module Main where

import Prelude

import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe)
import Data.Monoid (class Monoid, mempty)
import Data.Newtype (class Newtype, unwrap)
import Data.StrMap (StrMap)

data V e a = Invalid e | Valid e a
derive instance functorV ∷ Functor (V e)

valid ∷ ∀ a e. (Monoid e) ⇒ a → V e a
valid a = Valid mempty a

newtype Validation m e a b = Validation (a → m (V e b))
derive instance newtypeVaildation ∷ Newtype (Validation m e a b) _
derive instance functorValidation ∷ (Functor m) ⇒ Functor (Validation m e a)

instance applyValidation ∷ (Semigroup e, Monad m) ⇒ Apply (Validation m e a) where
  apply vf va = Validation $ \i → do
    vf' ← unwrap vf i
    va' ← unwrap va i
    pure $ case vf', va' of
      Valid m1 f, Valid m2 a → Valid (m1 <> m2) (f a)
      Invalid m1, Valid m2 _ → Invalid (m1 <> m2)
      Invalid m1, Invalid m2 → Invalid (m1 <> m2)
      Valid m1 _, Invalid m2 → Invalid (m1 <> m2)

instance semigroupoidValidation ∷ (Monad m, Semigroup e) ⇒ Semigroupoid (Validation m e) where
  compose v2 v1 =
    Validation $ (\a → do
      eb ← unwrap v1 a
      case eb of
        Valid e b → do
          r ← unwrap v2 b
          pure $ case r of
            Valid e' c → Valid (e <> e') c
            Invalid e' → Invalid (e <> e')
        Invalid e → pure (Invalid e))


data Form = Form (Array String) (Array Field)
derive instance genericForm ∷ Generic Form _
instance showForm ∷ Show Form where show = genericShow

instance semigroupForm ∷ Semigroup Form where
  append (Form e1 f1) (Form e2 f2)
    = Form (e1 <> e2) (f1 <> f2)

instance monoidForm ∷ Monoid Form where
  mempty = Form [] []

-- | Move to this representation
data FormValue a = Err String String | Val (Maybe a)
derive instance genericFormValue ∷ Generic (FormValue a) _
instance showFormValue ∷ (Show a) ⇒ Show (FormValue a) where show = genericShow

type Value = String
type Checked = Boolean
type Label = String
newtype Option = Option
  { value ∷ String
  , checked ∷ Boolean
  , label ∷ String
  }
derive instance newtypeOption ∷ Newtype Option _
derive instance genericOption ∷ Generic Option _
instance showOption ∷ Show Option where
  show = genericShow
type Options = Array Option
option v c l = Option { value: v, checked: c, label: l }

data Field
  = Input { label ∷ String, name ∷ String, value ∷ FormValue String }
  | Password { label ∷ String, name ∷ String, value ∷ FormValue String }
  | Number { label ∷ String, name ∷ String, value ∷ FormValue Int }
  -- | Radio { label ∷ String, name ∷ String, value ∷ Value Boolean }
  -- | Select { label ∷ String, name ∷ String, options ∷ Array (Tuple String String), value ∷ FormValue String}
  -- | Checkbox { label ∷ String, name ∷ String, value ∷ Either (Tuple String Options) Options }
derive instance genericField ∷ Generic Field _
instance showField ∷ Show Field where show = genericShow


-- | http query representation
type Query = StrMap (Array (Maybe String))


main :: forall e. Eff (console :: CONSOLE | e) Unit
main = do
  log "Hello sailor!"