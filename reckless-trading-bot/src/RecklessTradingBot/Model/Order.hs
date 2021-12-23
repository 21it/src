{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_HADDOCK show-extensions #-}

module RecklessTradingBot.Model.Order
  ( create,
    bfxUpdate,
    updateStatus,
    getByStatus,
  )
where

import qualified BitfinexClient as Bfx
import qualified Database.Persist as P
import RecklessTradingBot.Class.Storage
import RecklessTradingBot.Import
import qualified RecklessTradingBot.Import.Psql as Psql

create ::
  ( Storage m
  ) =>
  Entity Price ->
  m (Entity Order)
create (Entity priceId _) = do
  row <- liftIO $ newOrder <$> getCurrentTime
  rowId <- runSql $ P.insert row
  pure $ Entity rowId row
  where
    newOrder ct =
      Order
        { orderPrice = priceId,
          orderExtRef = Nothing,
          --
          -- TODO : !!!
          --
          orderGain = from @(Ratio Natural) 0,
          orderLoss = from @(Ratio Natural) 0,
          orderFee = [Bfx.feeRateMakerBase| 0 |],
          orderStatus = OrderNew,
          orderInsertedAt = ct,
          orderUpdatedAt = ct
        }

bfxUpdate ::
  ( Storage m
  ) =>
  OrderId ->
  Bfx.Order 'Bfx.Buy 'Bfx.Remote ->
  m ()
bfxUpdate orderId bfxOrder = do
  ct <- liftIO getCurrentTime
  runSql $
    Psql.update $ \row -> do
      Psql.set
        row
        [ OrderExtRef
            Psql.=. Psql.val
              ( Just . from $
                  Bfx.orderId bfxOrder
              ),
          OrderStatus
            Psql.=. Psql.val
              ( newOrderStatus $
                  Bfx.orderStatus bfxOrder
              ),
          OrderUpdatedAt
            Psql.=. Psql.val ct
        ]
      Psql.where_
        ( row Psql.^. OrderId
            Psql.==. Psql.val orderId
        )

updateStatus ::
  ( Storage m
  ) =>
  OrderStatus ->
  [OrderId] ->
  m ()
updateStatus ss xs = do
  ct <- liftIO getCurrentTime
  runSql $
    Psql.update $ \row -> do
      Psql.set
        row
        [ OrderStatus Psql.=. Psql.val ss,
          OrderUpdatedAt Psql.=. Psql.val ct
        ]
      Psql.where_ $
        row Psql.^. OrderId `Psql.in_` Psql.valList xs

getByStatus ::
  ( Storage m
  ) =>
  Bfx.CurrencyPair ->
  [OrderStatus] ->
  m [(Entity Order, Entity Price)]
getByStatus sym ss =
  runSql $
    Psql.select $
      Psql.from $ \(order `Psql.InnerJoin` price) -> do
        Psql.on
          ( order Psql.^. OrderPrice
              Psql.==. price Psql.^. PriceId
          )
        Psql.where_
          ( ( order Psql.^. OrderStatus
                `Psql.in_` Psql.valList ss
            )
              Psql.&&. ( price Psql.^. PriceBase
                           Psql.==. Psql.val
                             ( Bfx.currencyPairBase sym
                             )
                       )
              Psql.&&. ( price Psql.^. PriceQuote
                           Psql.==. Psql.val
                             ( Bfx.currencyPairQuote sym
                             )
                       )
          )
        --
        -- TODO : this limit might be a problem, in case where
        -- are order which changed status already, but are out
        -- of range of this limit. Might be useful to use
        -- updatedAt field for ordering to not miss updated
        -- data in long-term.
        --
        Psql.limit 1000
        pure (order, price)
