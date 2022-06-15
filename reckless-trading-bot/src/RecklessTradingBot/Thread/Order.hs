{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_HADDOCK show-extensions #-}

module RecklessTradingBot.Thread.Order
  ( apply,
    cancelExpired,
    cancelUnexpected,
  )
where

import qualified BitfinexClient as Bfx
import qualified BitfinexClient.Data.CancelOrderMulti as BfxCancel
import qualified BitfinexClient.Data.SubmitOrder as Bfx
import qualified Data.Set as Set
import RecklessTradingBot.Import
import qualified RecklessTradingBot.Model.Order as Order
import qualified RecklessTradingBot.Model.Trade as Trade

-- | This thread **must** be the only one
-- which is doing insert/update access to Order
-- model. Bot business logic is quite simple,
-- and I assume there is the only one instance
-- running. This way I can avoid lock-by-row
-- transactional complexity of postgres
-- procedures, and do simple insert/update instead.
apply :: (Env m) => m ()
apply = do
  $(logTM) DebugS "Spawned"
  forever $ do
    mma <- rcvNextMma
    let sym = Bfx.mmaSymbol mma
    withOperativeBfx $ do
      cancelUnexpected =<< Order.getByStatusLimit sym [OrderNew]
      placeOrder mma

cancelExpired :: (Env m) => [Entity Order] -> m ()
cancelExpired entities = do
  expiredOrders <-
    getExpiredOrders entities
  res <-
    runExceptT $
      cancelExpiredT expiredOrders
  whenLeft res $
    $(logTM) ErrorS . show

cancelExpiredT ::
  ( Env m
  ) =>
  [Entity Order] ->
  ExceptT Error m ()
cancelExpiredT [] = pure ()
cancelExpiredT entities = do
  $(logTM) DebugS $ show entities
  ids <-
    mapM
      ( \x ->
          tryJust
            ( ErrorRuntime $
                "Missing orderExtRef in "
                  <> show x
            )
            . (from <$>)
            . orderExtRef
            $ entityVal x
      )
      entities
  cids <-
    mapM
      ( \(Entity id0 x) -> do
          id1 <- tryFromT id0
          pure (id1, orderInsertedAt x)
      )
      entities
  gids <-
    mapM tryFromT $ entityKey <$> entities
  void $
    withBfxT
      Bfx.cancelOrderMulti
      ($ BfxCancel.ByOrderId $ Set.fromList ids)
  void $
    withBfxT
      Bfx.cancelOrderMulti
      ($ BfxCancel.ByOrderClientId $ Set.fromList cids)
  void $
    withBfxT
      Bfx.cancelOrderMulti
      ($ BfxCancel.ByOrderGroupId $ Set.fromList gids)

cancelUnexpected :: (Env m) => [Entity Order] -> m ()
cancelUnexpected [] = pure ()
cancelUnexpected entities = do
  res <-
    runExceptT $
      cancelUnexpectedT entities
  whenLeft res $
    $(logTM) ErrorS . show

cancelUnexpectedT ::
  ( Env m
  ) =>
  [Entity Order] ->
  ExceptT Error m ()
cancelUnexpectedT [] = pure ()
cancelUnexpectedT entities = do
  $(logTM) ErrorS $ show entities
  cids <-
    mapM
      ( \(Entity id0 x) -> do
          id1 <- tryFromT id0
          pure (id1, orderInsertedAt x)
      )
      entities
  gids <-
    mapM tryFromT ids
  void $
    withBfxT
      Bfx.cancelOrderMulti
      ($ BfxCancel.ByOrderClientId $ Set.fromList cids)
  void $
    withBfxT
      Bfx.cancelOrderMulti
      ($ BfxCancel.ByOrderGroupId $ Set.fromList gids)
  lift $
    Order.updateStatus OrderUnexpected ids
  where
    ids =
      entityKey <$> entities

placeOrder :: (Env m) => Bfx.Mma -> m ()
placeOrder mma = do
  res <-
    runExceptT $ do
      cfg <- getTradeCfg
      tradeEnt <- Trade.createUpdate mma
      let entryRate = tradeEntry $ entityVal tradeEnt
      let entryGain = tradeEnvMinBuyAmt cfg
      entryLoss <-
        tryErrorT . Bfx.roundMoney' $
          Bfx.unQuotePerBase entryRate |*| Bfx.unMoney entryGain
      quoteBalance <-
        withBfxT
          Bfx.spendableExchangeBalance
          ($ Bfx.currencyPairQuote $ Bfx.mmaSymbol mma)
      when (quoteBalance > entryLoss) $
        placeOrderT cfg tradeEnt
  whenLeft res $
    $(logTM) ErrorS . show

placeOrderT ::
  ( Env m
  ) =>
  TradeEnv ->
  Entity Trade ->
  ExceptT Error m ()
placeOrderT cfg tradeEnt = do
  orderEnt@(Entity orderId order) <-
    lift $
      Order.create cfg tradeEnt
  $(logTM) DebugS . logStr $
    "Placing a new order " <> (show orderEnt :: Text)
  cid <- tryFromT orderId
  gid <- tryFromT orderId
  bfxOrder <-
    withBfxT
      Bfx.submitOrderMaker
      ( \cont ->
          cont
            (orderGain order)
            (tradeEnvCurrencyPair cfg)
            (tradeEntry $ entityVal tradeEnt)
            Bfx.optsPostOnly
              { Bfx.clientId = Just cid,
                Bfx.groupId = Just gid
              }
      )
  lift $
    Order.updateBfx orderId bfxOrder
