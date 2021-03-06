module Polyform.Field.Validation.Combinators where

import Prelude

import Data.Array (catMaybes, uncons)
import Data.Int (fromString)
import Data.Maybe (Maybe(..))
import Data.NonEmpty (NonEmpty(..))
import Data.Variant (Variant, inj, on)
import Polyform.Validation (V(..), Validation, hoistFnMV, hoistFnV, runValidation)
import Type.Prelude (class IsSymbol, SProxy(SProxy))
import Prim.Row (class Cons)

-- | These helpers seems rather useful only
-- | in case of field validation scenarios
-- | so they are here.
check
  ∷ ∀ a e m
  . Monad m
  ⇒ Monoid e
  ⇒ (a → e)
  → (a → Boolean)
  → Validation m e a a
check singleton f = hoistFnV $ \i →
  let
    e = singleton i
  in
    if f i
      then Valid e i
      else Invalid e

checkAndTag
  ∷ ∀ a e err e' m n
  . Monad m
  ⇒ Cons n a e' e
  ⇒ IsSymbol n
  ⇒ Monoid err
  ⇒ (Variant e → err)
  → SProxy n
  → (a -> Boolean)
  → Validation m err a a
checkAndTag singleton n c = check (inj n >>> singleton) c

_scalar = (SProxy ∷ SProxy "scalar")

scalar
  ∷ ∀ a err m r
  . (Monad m)
  ⇒ (Monoid err)
  ⇒ (Variant (scalar ∷ NonEmpty Array a | r) → err)
  → Validation m err (NonEmpty Array a) a
scalar singleton = hoistFnV $ case _ of
  NonEmpty a [] → pure a
  arr → Invalid (singleton (inj _scalar arr))

_required = SProxy ∷ SProxy "required"

required
  ∷ ∀ a err m r
  . Monad m
  ⇒ Monoid err
  ⇒ (Variant (required ∷ Unit | r) → err)
  → Validation m err (Array a) (NonEmpty Array a)
required singleton = hoistFnV $ case _ of
  [] → Invalid (singleton (inj _required unit))
  arr → case uncons arr of
    Nothing → Invalid (singleton (inj _required unit))
    Just { head, tail } → pure (NonEmpty head tail)

opt
  ∷ ∀ e i m o
  . Monad m
  ⇒ Validation
        m
        (Array (Variant ( required ∷ Unit | e)))
        i
        o
  → Validation m (Array (Variant e)) i (Maybe o)
opt v = hoistFnMV \i → do
  result ← runValidation v i
  pure $ case result of
    Valid e o → Valid (catMaybes <<< map dropRequired $ e) (Just o)
    Invalid e → case catMaybes <<< map dropRequired $ e of
      [] → Valid [] Nothing
      e' → Invalid e'
  where
  dropRequired = (Just # on (SProxy ∷ SProxy "required") (const Nothing))

_int = SProxy ∷ SProxy "int"

type IntErr e = (int ∷ String | e)

int
  ∷ ∀ m err r
  . Monad m
  ⇒ Monoid err
  ⇒ (Variant (IntErr r) → err)
  → Validation m err String Int -- err String Int
int singleton = hoistFnV (\i → case fromString i of
  Just a → pure a
  Nothing → Invalid $ singleton (inj _int i))

