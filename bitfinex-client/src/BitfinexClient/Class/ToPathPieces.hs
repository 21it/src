{-# LANGUAGE AllowAmbiguousTypes #-}
{-# OPTIONS_HADDOCK show-extensions #-}

module BitfinexClient.Class.ToPathPieces
  ( ToPathPieces (..),
  )
where

import BitfinexClient.Class.ToRequestParam
import qualified BitfinexClient.Data.GetOrders as GetOrders
import BitfinexClient.Data.Kind
import BitfinexClient.Import.External

class ToPathPieces (method :: Method) req where
  toPathPieces :: req -> [Text]

instance ToPathPieces 'SymbolsDetails req where
  toPathPieces =
    const ["v1", "symbols_details"]

instance ToPathPieces 'MarketAveragePrice req where
  toPathPieces =
    const ["v2", "calc", "trade", "avg"]

instance ToPathPieces 'FeeSummary req where
  toPathPieces =
    const ["v2", "auth", "r", "summary"]

instance ToPathPieces 'SubmitOrder req where
  toPathPieces =
    const ["v2", "auth", "w", "order", "submit"]

instance ToPathPieces 'RetrieveOrders GetOrders.Options where
  toPathPieces x =
    [ "v2",
      "auth",
      "r",
      "orders"
    ]
      <> maybeToList
        ( toTextParam <$> GetOrders.currencyPair x
        )

instance ToPathPieces 'OrdersHistory GetOrders.Options where
  toPathPieces x =
    [ "v2",
      "auth",
      "r",
      "orders"
    ]
      <> maybeToList
        ( toTextParam <$> GetOrders.currencyPair x
        )
      <> [ "hist"
         ]

instance ToPathPieces 'CancelOrderMulti req where
  toPathPieces =
    const
      [ "v2",
        "auth",
        "w",
        "order",
        "cancel",
        "multi"
      ]

instance ToPathPieces 'Wallets req where
  toPathPieces =
    const
      [ "v2",
        "auth",
        "r",
        "wallets"
      ]
