{-# OPTIONS_HADDOCK show-extensions #-}

module RecklessTradingBot.Class.Env
  ( Env (..),
  )
where

import qualified BitfinexClient as Bfx
import RecklessTradingBot.Class.Storage
import qualified RecklessTradingBot.Data.Env as E
import RecklessTradingBot.Data.Model
import RecklessTradingBot.Data.Type
import RecklessTradingBot.Import.External

class (Storage m, KatipContext m) => Env m where
  withBfx ::
    (Bfx.Env -> a) ->
    (a -> ExceptT Bfx.Error m b) ->
    m (Either Error b)
  withBfx method =
    runExceptT . withBfxT method
  withBfxT ::
    (Bfx.Env -> a) ->
    (a -> ExceptT Bfx.Error m b) ->
    ExceptT Error m b
  getTeleEnv :: m E.TeleEnv
  getTradeVar :: m (MVar (Map Bfx.CurrencyPair E.TradeEnv))
  getTradeEnv :: Bfx.CurrencyPair -> ExceptT Error m E.TradeEnv
  getExpiredOrders :: [Entity Order] -> m [Entity Order]
  putCurrMma :: Bfx.Mma -> m ()
  rcvNextMma :: m Bfx.Mma
  getLastMma :: m (Maybe Bfx.Mma)
  getReportStartAmt :: m (Bfx.Money 'Bfx.Quote 'Bfx.Sell)
  getReportCurrency :: m (Bfx.CurrencyCode 'Bfx.Quote)
  getBaseBlacklist :: m (Set (Bfx.CurrencyCode 'Bfx.Base))
