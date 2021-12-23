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

    Price
      base (Bfx.CurrencyCode 'Bfx.Base)
      quote (Bfx.CurrencyCode 'Bfx.Quote)
      buy (Bfx.QuotePerBase 'Bfx.Buy)
      sell (Bfx.QuotePerBase 'Bfx.Sell)
      insertedAt UTCTime
      updatedAt UTCTime
      deriving Eq Show

    Order
      --
      -- Price which triggered the Order
      --
      price PriceId
      extRef (OrderExternalId 'Bfx.Buy) Maybe
      gain (Bfx.MoneyBase 'Bfx.Buy)
      loss (Bfx.MoneyQuote 'Bfx.Buy)
      fee (Bfx.FeeRate 'Bfx.Maker 'Bfx.Base)
      status OrderStatus
      insertedAt UTCTime
      updatedAt UTCTime
      deriving Eq Show

    CounterOrder
      intRef OrderId
      extRef (OrderExternalId 'Bfx.Sell) Maybe
      price (Bfx.QuotePerBase 'Bfx.Sell)
      gain (Bfx.MoneyQuote 'Bfx.Sell)
      loss (Bfx.MoneyBase 'Bfx.Sell)
      fee (Bfx.FeeRate 'Bfx.Maker 'Bfx.Quote)
      status OrderStatus
      at UTCTime
      deriving Eq Show

  |]
