{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_HADDOCK show-extensions #-}

module BitfinexClient.Data.Type
  ( -- * Orders
    -- $orders
    OrderId (..),
    OrderClientId (..),
    OrderGroupId (..),
    Order (..),
    OrderFlag (..),
    OrderFlagAcc (..),
    unOrderFlag,
    unOrderFlagSet,
    OrderStatus (..),
    newOrderStatus,

    -- * Trading
    -- $trading
    ExchangeAction (..),
    newExchangeAction,
    FeeRate (..),
    RebateRate (..),
    ProfitRate (..),
    CurrencyCode (..),
    CurrencyPair,
    currencyPairBase,
    currencyPairQuote,
    newCurrencyPair,
    newCurrencyPair',
    CurrencyPairConf (..),

    -- * Misc
    -- $misc
    PosRat,
    unPosRat,
    subPosRat,
    bfxRoundRatio,
    Error (..),
    tryErrorE,
    tryErrorT,
    tryFromE,
    tryFromT,
  )
where

import BitfinexClient.Class.ToRequestParam
import BitfinexClient.Data.Kind
import BitfinexClient.Data.Metro
import BitfinexClient.Import.External
import Data.Aeson (withObject, (.:))
import qualified Data.Text as T
import Language.Haskell.TH.Syntax as TH (Lift)
import qualified Network.HTTP.Client as Web

-- $orders
-- Order data received from Bitfinex
-- and types related to orders.

newtype OrderId
  = OrderId Natural
  deriving newtype
    ( Eq,
      Ord,
      Show,
      Num,
      ToJSON,
      FromJSON
    )
  deriving stock
    ( Generic
    )

instance From Natural OrderId

instance From OrderId Natural

instance TryFrom Int64 OrderId where
  tryFrom =
    from @Natural `composeTryRhs` tryFrom

instance TryFrom OrderId Int64 where
  tryFrom =
    tryFrom @Natural `composeTryLhs` from

newtype OrderClientId
  = OrderClientId Natural
  deriving newtype
    ( Eq,
      Ord,
      Show,
      Num,
      ToJSON,
      FromJSON
    )
  deriving stock
    ( Generic
    )

instance From Natural OrderClientId

instance From OrderClientId Natural

newtype OrderGroupId
  = OrderGroupId Natural
  deriving newtype
    ( Eq,
      Ord,
      Show,
      Num,
      ToJSON,
      FromJSON
    )
  deriving stock
    ( Generic
    )

instance From Natural OrderGroupId

instance From OrderGroupId Natural

data Order (a :: Location) = Order
  { orderId :: OrderId,
    orderGroupId :: Maybe OrderGroupId,
    -- | Field might be auto-generated by Bitfinex in case where
    -- it was not provided through 'BitfinexClient.Data.SubmitOrder.Options'.
    orderClientId :: Maybe OrderClientId,
    orderAction :: ExchangeAction,
    orderAmount :: MoneyBase,
    orderSymbol :: CurrencyPair,
    orderRate :: QuotePerBase,
    orderStatus :: OrderStatus
  }
  deriving stock
    ( Eq,
      Ord,
      Show,
      Generic
    )

data OrderFlag
  = Hidden
  | Close
  | ReduceOnly
  | PostOnly
  | Oco
  | NoVarRates
  deriving stock
    ( Eq,
      Ord,
      Show,
      Generic,
      Enum,
      Bounded
    )

newtype OrderFlagAcc
  = OrderFlagAcc Natural
  deriving newtype
    ( Eq,
      Ord,
      Show,
      Num,
      ToJSON,
      FromJSON
    )
  deriving stock
    ( Generic
    )

unOrderFlag :: OrderFlag -> OrderFlagAcc
unOrderFlag =
  OrderFlagAcc . \case
    Hidden -> 64
    Close -> 512
    ReduceOnly -> 1024
    PostOnly -> 4096
    Oco -> 16384
    NoVarRates -> 524288

unOrderFlagSet :: Set OrderFlag -> OrderFlagAcc
unOrderFlagSet =
  foldr (\x acc -> acc + unOrderFlag x) $ OrderFlagAcc 0

data OrderStatus
  = Active
  | Executed
  | PartiallyFilled
  | InsufficientMargin
  | Canceled
  | PostOnlyCanceled
  | RsnDust
  | RsnPause
  deriving stock
    ( Eq,
      Ord,
      Show,
      Generic,
      Enum,
      Bounded
    )

newOrderStatus ::
  Text ->
  Either (TryFromException Text OrderStatus) OrderStatus
newOrderStatus = \case
  "ACTIVE" -> Right Active
  x | "EXECUTED" `T.isPrefixOf` x -> Right Executed
  x | "PARTIALLY FILLED" `T.isPrefixOf` x -> Right PartiallyFilled
  x | "INSUFFICIENT MARGIN" `T.isPrefixOf` x -> Right InsufficientMargin
  "CANCELED" -> Right Canceled
  "POSTONLY CANCELED" -> Right PostOnlyCanceled
  "RSN_DUST" -> Right RsnDust
  "RSN_PAUSE" -> Right RsnPause
  x -> Left $ TryFromException x Nothing

-- $trading
-- Data related to trading and money.

data ExchangeAction
  = Buy
  | Sell
  deriving stock
    ( Eq,
      Ord,
      Show,
      Generic,
      Enum,
      Bounded
    )

newExchangeAction ::
  Rational ->
  Either (TryFromException Rational ExchangeAction) ExchangeAction
newExchangeAction x
  | x > 0 = Right Buy
  | x < 0 = Right Sell
  | otherwise = Left $ TryFromException x Nothing

newtype
  FeeRate
    (a :: MarketRelation)
    (b :: CurrencyRelation) = FeeRate
  { unFeeRate :: Ratio Natural
  }
  deriving newtype
    ( Eq,
      Ord,
      Show
    )
  deriving stock
    ( Generic,
      TH.Lift
    )

instance From (FeeRate a b) (Ratio Natural)

instance TryFrom (Ratio Natural) (FeeRate a b) where
  tryFrom x
    | x < 1 = Right $ FeeRate x
    | otherwise = Left $ TryFromException x Nothing

instance From (FeeRate a b) Rational where
  from = via @(Ratio Natural)

instance TryFrom Rational (FeeRate a b) where
  tryFrom = tryVia @(Ratio Natural)

newtype RebateRate (a :: MarketRelation)
  = RebateRate Rational
  deriving newtype
    ( Eq,
      Ord,
      Show,
      Num
    )
  deriving stock
    ( Generic
    )

instance From (RebateRate a) Rational

instance From Rational (RebateRate a)

newtype ProfitRate = ProfitRate
  { unProfitRate :: PosRat
  }
  deriving newtype
    ( Eq,
      Ord,
      Show
    )
  deriving stock
    ( Generic
    )

instance From ProfitRate PosRat

instance From PosRat ProfitRate

instance From ProfitRate (Ratio Natural) where
  from = via @PosRat

instance TryFrom (Ratio Natural) ProfitRate where
  tryFrom =
    from @PosRat
      `composeTryRhs` tryFrom

instance TryFrom Rational ProfitRate where
  tryFrom =
    from @PosRat
      `composeTryRhs` tryFrom

instance From ProfitRate Rational where
  from = via @PosRat

--
-- TODO : add Buy/Sell phantom kind param
--
instance ToRequestParam (ExchangeAction, MoneyBase) where
  toTextParam (act, amt) =
    toTextParam $
      case act of
        Buy -> absAmt
        Sell -> (-1) * absAmt
    where
      absAmt = abs $ into @Rational amt

newtype CurrencyCode (a :: CurrencyRelation) = CurrencyCode
  { unCurrencyCode :: Text
  }
  deriving newtype
    ( Eq,
      Ord,
      Show,
      --
      -- TODO : maybe we want to handle it as
      -- case-insensitive Text
      --
      ToJSON,
      FromJSON,
      IsString
    )
  deriving stock
    ( Generic,
      TH.Lift
    )

data CurrencyPair = CurrencyPair
  { currencyPairBase :: CurrencyCode 'Base,
    currencyPairQuote :: CurrencyCode 'Quote
  }
  deriving stock
    ( Eq,
      Ord,
      Show,
      Generic,
      TH.Lift
    )

instance FromJSON CurrencyPair where
  parseJSON = withObject "CurrencyPair" $ \x0 -> do
    base <- x0 .: "base"
    quote <- x0 .: "quote"
    case newCurrencyPair base quote of
      Left x -> fail $ show x
      Right x -> pure x

instance ToRequestParam CurrencyPair where
  toTextParam x =
    "t"
      <> (coerce $ currencyPairBase x :: Text)
      <> (coerce $ currencyPairQuote x :: Text)

newCurrencyPair ::
  CurrencyCode 'Base ->
  CurrencyCode 'Quote ->
  Either
    ( TryFromException
        ( CurrencyCode 'Base,
          CurrencyCode 'Quote
        )
        CurrencyPair
    )
    CurrencyPair
newCurrencyPair base quote =
  if unCurrencyCode base == unCurrencyCode quote
    then
      Left $
        TryFromException (base, quote) Nothing
    else
      Right $
        CurrencyPair base quote

newCurrencyPair' ::
  Text ->
  Either (TryFromException Text CurrencyPair) CurrencyPair
newCurrencyPair' raw
  | (length raw == 7) && (prefix == "t") = do
    let (base0, quote0) = T.splitAt 3 xs
    first (withSource raw) $
      newCurrencyPair
        (CurrencyCode $ T.toUpper base0)
        (CurrencyCode $ T.toUpper quote0)
  | length raw == 6 = do
    let (base0, quote0) = T.splitAt 3 raw
    first (withSource raw) $
      newCurrencyPair
        (CurrencyCode $ T.toUpper base0)
        (CurrencyCode $ T.toUpper quote0)
  | otherwise =
    Left $ TryFromException raw Nothing
  where
    (prefix, xs) = T.splitAt 1 raw

data CurrencyPairConf = CurrencyPairConf
  { currencyPairPrecision :: Natural,
    currencyPairInitMargin :: PosRat,
    currencyPairMinMargin :: PosRat,
    currencyPairMaxOrderAmt :: MoneyBase,
    currencyPairMinOrderAmt :: MoneyBase
  }
  deriving stock
    ( Eq,
      Ord,
      Show,
      Generic
    )

-- $misc
-- General utility data used elsewhere.

newtype PosRat = PosRat
  { unPosRat :: Ratio Natural
  }
  deriving newtype
    ( Eq,
      Ord,
      Show,
      ToRequestParam
    )
  deriving stock
    ( Generic,
      TH.Lift
    )

instance From PosRat (Ratio Natural)

instance TryFrom (Ratio Natural) PosRat where
  tryFrom x
    | x > 0 = Right $ PosRat x
    | otherwise = Left $ TryFromException x Nothing

instance TryFrom Rational PosRat where
  tryFrom = tryVia @(Ratio Natural)

instance From PosRat Rational where
  from = via @(Ratio Natural)

subPosRat :: PosRat -> PosRat -> Either Error PosRat
subPosRat x0 x1
  | x0 > x1 =
    first
      (const failure)
      . tryFrom @(Ratio Natural)
      $ from x0 - from x1
  | otherwise = Left failure
  where
    failure =
      ErrorMath $
        "Expression "
          <> show x0
          <> " - "
          <> show x1
          <> " is not PosRat"

bfxRoundRatio :: (From a Rational) => a -> Rational
bfxRoundRatio =
  sdRound 5
    . dpRound 8
    . from

--
-- TODO : implement Eq/Ord?
--
data Error
  = ErrorWebException HttpException
  | ErrorWebPub Web.Request (Web.Response ByteString)
  | ErrorWebPrv ByteString Web.Request (Web.Response ByteString)
  | ErrorParser Web.Request (Web.Response ByteString) Text
  | --
    -- TODO : remove ErrorSmartCon
    --
    ErrorSmartCon Text
  | ErrorMath Text
  | ErrorTryFrom SomeException
  | ErrorMissingOrder OrderId
  | ErrorUnverifiedOrder (Order 'Local) (Order 'Remote)
  | ErrorOrderState (Order 'Remote)
  deriving stock
    ( Show,
      Generic
    )

tryErrorE ::
  forall a b.
  ( Show a,
    Typeable a,
    Typeable b
  ) =>
  Either (TryFromException a b) b ->
  Either Error b
tryErrorE =
  first $
    ErrorTryFrom . SomeException

tryErrorT ::
  forall a b m.
  ( Show a,
    Typeable a,
    Typeable b,
    Monad m
  ) =>
  Either (TryFromException a b) b ->
  ExceptT Error m b
tryErrorT =
  except . tryErrorE

tryFromE ::
  forall a b.
  ( Show a,
    Typeable a,
    Typeable b,
    TryFrom a b
  ) =>
  a ->
  Either Error b
tryFromE =
  tryErrorE . tryFrom

tryFromT ::
  forall a b m.
  ( Show a,
    Typeable a,
    Typeable b,
    TryFrom a b,
    Monad m
  ) =>
  a ->
  ExceptT Error m b
tryFromT =
  except . tryFromE
