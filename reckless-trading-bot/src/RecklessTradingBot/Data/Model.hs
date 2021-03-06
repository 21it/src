{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-missing-export-lists #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}
{-# OPTIONS_HADDOCK show-extensions #-}

module RecklessTradingBot.Data.Model where

import qualified BitfinexClient as Bfx
import Database.Persist.TH
import RecklessTradingBot.Data.Type
import RecklessTradingBot.Import.External

--
-- You can define all of your database entities in the entities file.
-- You can find more information on persistent and how to declare entities
-- at:
-- http://www.yesodweb.com/book/persistent/
--
-- Syntax for models:
-- https://github.com/yesodweb/persistent/blob/master/docs/Persistent-entity-syntax.md
--
share
  [mkPersist sqlSettings, mkMigrate "migrateAuto"]
  [persistLowerCase|

    Trade
      base (Bfx.CurrencyCode 'Bfx.Base)
      quote (Bfx.CurrencyCode 'Bfx.Quote)
      entry (Bfx.QuotePerBase 'Bfx.Buy)
      takeProfit (Bfx.QuotePerBase 'Bfx.Sell)
      stopLoss (Bfx.QuotePerBase 'Bfx.Sell)
      insertedAt UTCTime
      updatedAt UTCTime
      deriving Eq Show

    Order
      intRef TradeId
      extRef (OrderExternalId 'Bfx.Buy) Maybe
      price (Bfx.QuotePerBase 'Bfx.Buy)
      gain (Bfx.Money 'Bfx.Base 'Bfx.Buy)
      loss (Bfx.Money 'Bfx.Quote 'Bfx.Buy)
      fee (Bfx.FeeRate 'Bfx.Taker 'Bfx.Base)
      status OrderStatus
      insertedAt UTCTime
      updatedAt UTCTime
      deriving Eq Show

    CounterOrder
      intRef OrderId
      extRef (OrderExternalId 'Bfx.Sell) Maybe
      price (Bfx.QuotePerBase 'Bfx.Sell)
      gain (Bfx.Money 'Bfx.Quote 'Bfx.Sell)
      loss (Bfx.Money 'Bfx.Base 'Bfx.Sell)
      fee (Bfx.FeeRate 'Bfx.Taker 'Bfx.Quote)
      status OrderStatus
      insertedAt UTCTime
      updatedAt UTCTime
      deriving Eq Show

  |]
