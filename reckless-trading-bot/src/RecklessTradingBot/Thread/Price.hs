{-# OPTIONS_HADDOCK show-extensions #-}

module RecklessTradingBot.Thread.Price (apply) where

import qualified BitfinexClient as Bfx
import RecklessTradingBot.Import
import qualified RecklessTradingBot.Model.Price as Price

apply :: Env m => m ()
apply = do
  xs <- mapM (spawnLink . loop) . toList =<< getPairs
  liftIO . void $ waitAny xs

loop :: Env m => TradingConf -> m ()
loop cfg = do
  sleepTillNextPrice $ tradingConfPair cfg
  createPrice cfg
  loop cfg

createPrice :: Env m => TradingConf -> m ()
createPrice cfg = do
  amt <-
    coerce
      <$> readMVar (tradingConfMinOrderAmt cfg)
  let getPrice x =
        Bfx.marketAveragePrice x amt sym
  res <-
    runExceptT . withExceptT ErrorBfx $
      (,) <$> getPrice Bfx.Buy <*> getPrice Bfx.Sell
  print res
  case res of
    --
    -- TODO : log error and do something
    --
    Left {} ->
      sleep $ Seconds 60
    Right (buy, sell) ->
      void $
        Price.create
          sym
          (ExchangeRate buy)
          (ExchangeRate sell)
  where
    sym = tradingConfPair cfg

spawnLink :: MonadUnliftIO m => m a -> m (Async a)
spawnLink x =
  withRunInIO $ \run -> do
    pid <- async $ run x
    link pid
    return pid