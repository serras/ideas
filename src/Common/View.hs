-----------------------------------------------------------------------------
-- Copyright 2008, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- This module defines views on data-types
--
-----------------------------------------------------------------------------
module Common.View 
   ( Match, View, makeView, Simplification, makeSimplification
   , match, matchM, build, canonical, canonicalM, canonicalWith
   , simplify, simplifyWith, isCanonical, isCanonicalWith
   , belongsTo, viewEquivalent, viewEquivalentWith
   , (>>>), Control.Arrow.Arrow(..), Control.Arrow.ArrowChoice(..), identity
   , listView, conversion, ( #> )
   , propIdempotence, propSoundness, propNormalForm
   ) where

import Control.Arrow hiding ((>>>))
import Control.Monad
import Data.Maybe
import Test.QuickCheck
import qualified Control.Category as C

-- For all v::View the following should hold:
--   1) simplify v a "is equivalent to" a
--   2) match (build b) equals Just b  
--         (but only for b that have at least one "a")
--
-- Derived property: simplification is idempotent

type Match a b = a -> Maybe b

data View a b = View 
   { match :: Match a b
   , build :: b -> a
   }

type Simplification a = View a a

matchM :: Monad m => View a b -> a -> m b
matchM v = maybe (Prelude.fail "no match") return . match v

makeView :: (a -> Maybe b) -> (b -> a) -> View a b
makeView = View

makeSimplification :: (a -> a) -> Simplification a
makeSimplification f = makeView (return . f) id

canonical :: View a b -> a -> Maybe a
canonical = canonicalWith id

canonicalM :: Monad m => View a b -> a -> m a
canonicalM v = maybe (Prelude.fail "no match") return . canonicalWith id v

canonicalWith :: (b -> b) -> View a b -> a -> Maybe a
canonicalWith f view = liftM (build view . f) . match view

simplify :: View a b -> a -> a
simplify = simplifyWith id

simplifyWith :: (b -> b) -> View a b -> a -> a
simplifyWith f view a = fromMaybe a (canonicalWith f view a)

---------------------------------------------------------------

belongsTo :: a -> View a b -> Bool
belongsTo a view = isJust (match view a)

viewEquivalent :: Eq b => View a b -> a -> a -> Bool
viewEquivalent = viewEquivalentWith (==)

viewEquivalentWith :: (b -> b -> Bool) -> View a b -> a -> a -> Bool
viewEquivalentWith eq view x y =
   case (match view x, match view y) of
      (Just a, Just b) -> a `eq` b
      _                -> False
      
isCanonical :: Eq a => View a b -> a -> Bool
isCanonical = isCanonicalWith (==)
      
isCanonicalWith :: (a -> a -> Bool) -> View a b -> a -> Bool
isCanonicalWith eq v a = maybe False (eq a) (canonical v a)
      
---------------------------------------------------------------
-- Arrow combinators

identity :: View a a 
identity = makeView Just id

(>>>) :: View a b -> View b c -> View a c
v >>> w = makeView (\a -> match v a >>= match w) (build v . build w)

instance C.Category View where
   id    = identity
   v . w = w >>> v

instance Arrow View where
   arr f = makeView 
      (return . f) 
      (error "Control.View.arr: function is not invertible")

   first v = makeView 
      (\(a, c) -> match v a >>= \b -> return (b, c)) 
      (first (build v))

   second v = makeView 
      (\(a, b) -> match v b >>= \c -> return (a, c)) 
      (second (build v))

   v *** w = makeView 
      (\(a, c) -> liftM2 (,) (match v a) (match w c)) 
      (build v *** build w)

   -- left-biased builder
   v &&& w = makeView 
      (\a -> liftM2 (,) (match v a) (match w a)) 
      (\(b, _) -> build v b)

instance ArrowChoice View where
   left v = makeView 
      (either (liftM Left . match v) (return . Right)) 
      (either (Left . build v) Right)

   right v = makeView 
      (either (return . Left) (liftM Right . match v)) 
      (either Left (Right . build v))

   v +++ w = makeView 
      (either (liftM Left . match v) (liftM Right . match w))  
      (either (Left . build v) (Right . build w))

   -- left-biased builder
   v ||| w = makeView 
      (either (match v) (match w))
      (Left . build v)
      
---------------------------------------------------------------
-- More combinators

listView :: View a b -> View [a] [b]
listView v = makeView (mapM (match v)) (map (build v))

conversion :: (a -> b) -> (b -> a) -> View a b
conversion f g = makeView (Just . f) g

( #> ) :: (a -> Bool) -> View a b -> View a b
p #> v = makeView f (build v)
 where f a = guard (p a) >> match v a
 
---------------------------------------------------------------
-- Properties on views 

propIdempotence :: (Show a, Eq a) => Gen a -> View a b -> Property
propIdempotence g v = forAll g $ \a -> 
   let b = simplify v a
   in b == simplify v b

propSoundness :: Show a => (a -> a -> Bool) -> Gen a -> View a c -> Property
propSoundness semEq g v = forAll g $ \a -> 
   let b = simplify v a
   in semEq a b
   
propNormalForm :: (Show a, Eq a) => Gen a -> View a b -> Property
propNormalForm g v = forAll g $ \a -> a == simplify v a