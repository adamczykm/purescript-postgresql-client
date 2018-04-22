module Database.PostgreSQL.Value where

import Prelude

import Control.Monad.Eff (kind Effect)
import Control.Monad.Error.Class (throwError)
import Control.Monad.Except (runExcept)
import Data.Array as Array
import Data.Bifunctor (lmap)
import Data.ByteString (ByteString)
import Data.Date (Date, canonicalDate, day, month, year)
import Data.DateTime.Instant (Instant, instant)
import Data.Decimal (Decimal)
import Data.Decimal as Decimal
import Data.Either (Either(..), note)
import Data.Enum (fromEnum, toEnum)
import Data.Foreign (Foreign, isNull, readArray, readBoolean, readChar, readInt, readNumber, readString, toForeign, unsafeFromForeign)
import Data.Int (fromString)
import Data.List (List)
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), split)
import Data.Time.Duration (Milliseconds(..))
import Data.Traversable (traverse)

-- | Convert things to SQL values.
class ToSQLValue a where
    toSQLValue :: a -> Foreign

-- | Convert things from SQL values.
class FromSQLValue a where
    fromSQLValue :: Foreign -> Either String a

instance toSQLValueBoolean :: ToSQLValue Boolean where
    toSQLValue = toForeign

instance fromSQLValueBoolean :: FromSQLValue Boolean where
    fromSQLValue = lmap show <<< runExcept <<< readBoolean

instance toSQLValueChar :: ToSQLValue Char where
    toSQLValue = toForeign

instance fromSQLValueChar :: FromSQLValue Char where
    fromSQLValue = lmap show <<< runExcept <<< readChar

instance toSQLValueInt :: ToSQLValue Int where
    toSQLValue = toForeign

instance fromSQLValueInt :: FromSQLValue Int where
    fromSQLValue = lmap show <<< runExcept <<< readInt

instance toSQLValueNumber :: ToSQLValue Number where
    toSQLValue = toForeign

instance fromSQLValueNumber :: FromSQLValue Number where
    fromSQLValue = lmap show <<< runExcept <<< readNumber

instance toSQLValueString :: ToSQLValue String where
    toSQLValue = toForeign

instance fromSQLValueString :: FromSQLValue String where
    fromSQLValue = lmap show <<< runExcept <<< readString

instance toSQLValueArray :: (ToSQLValue a) => ToSQLValue (Array a) where
    toSQLValue = toForeign <<< map toSQLValue

instance fromSQLValueArray :: (FromSQLValue a) => FromSQLValue (Array a) where
    fromSQLValue = traverse fromSQLValue <=< lmap show <<< runExcept <<< readArray

instance toSQLValueList :: (ToSQLValue a) => ToSQLValue (List a) where
    toSQLValue = toForeign <<< Array.fromFoldable <<< map toSQLValue

instance fromSQLValueList :: (FromSQLValue a) => FromSQLValue (List a) where
    fromSQLValue = map List.fromFoldable <<< traverse fromSQLValue <=< lmap show <<< runExcept <<< readArray

instance toSQLValueByteString :: ToSQLValue ByteString where
    toSQLValue = toForeign

instance fromSQLValueByteString :: FromSQLValue ByteString where
    fromSQLValue x
        | unsafeIsBuffer x = pure $ unsafeFromForeign x
        | otherwise = throwError "FromSQLValue ByteString: not a buffer"

instance toSQLValueInstant :: ToSQLValue Instant where
    toSQLValue = instantToString

instance fromSQLValueInstant :: FromSQLValue Instant where
    fromSQLValue v = do
      t <- instantFromString Left Right v
      note ("Instant construction failed for given timestamp: " <> show t) $ instant (Milliseconds t)

instance toSQLValueDate :: ToSQLValue Date where
    toSQLValue date =
        let
            y = fromEnum $ year date
            m = fromEnum $ month date
            d = fromEnum $ day date
        in
            toForeign $ show y <> "-" <> show m <> "-" <> show d

instance fromSQLValueDate :: FromSQLValue Date where
    fromSQLValue v = do
        s <- lmap show $ runExcept (readString v)
        let
            msg = "Date parsing failed for value: " <> s
        case split (Pattern "-") s of
            [y, m, d] -> do
                let
                  result = canonicalDate
                    <$> (toEnum =<< fromString y)
                    <*> (toEnum =<< fromString m)
                    <*> (toEnum =<< fromString d)
                note msg result
            _ -> Left msg

instance toSQLValueMaybe :: (ToSQLValue a) => ToSQLValue (Maybe a) where
    toSQLValue Nothing = null
    toSQLValue (Just x) = toSQLValue x

instance fromSQLValueMaybe :: (FromSQLValue a) => FromSQLValue (Maybe a) where
    fromSQLValue x | isNull x  = pure Nothing
                   | otherwise = Just <$> fromSQLValue x

instance toSQLValueForeign :: ToSQLValue Foreign where
    toSQLValue = id

instance fromSQLValueForeign :: FromSQLValue Foreign where
    fromSQLValue = pure

instance toSQLValueDecimal :: ToSQLValue Decimal where
    toSQLValue = Decimal.toString >>> toForeign

instance fromSQLValueDecimal :: FromSQLValue Decimal where
    fromSQLValue v = do
        s <- lmap show $ runExcept (readString v)
        note ("Decimal literal parsing failed: " <> s) (Decimal.fromString s)

foreign import null :: Foreign
foreign import instantToString :: Instant -> Foreign
foreign import instantFromString :: (String -> Either String Number) -> (Number -> Either String Number) -> Foreign -> Either String Number
foreign import unsafeIsBuffer :: ∀ a. a -> Boolean
