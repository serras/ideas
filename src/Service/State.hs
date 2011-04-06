-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- The information maintained for a learner trying to complete a
-- derivation.
--
-----------------------------------------------------------------------------
module Service.State 
   ( -- * Exercise state
     State, makeState, empyStateContext, emptyState 
   , exercisePkg, statePrefix, stateContext, stateTerm
     -- * Types
   , stateType
   ) where

import Common.Library
import Common.Utils (readM)
import Data.Maybe
import Service.ExercisePackage
import Service.Types

data State a = State 
   { exercisePkg  :: ExercisePackage a
   , statePrefix  :: Maybe (Prefix (Context a))
   , stateContext :: Context a
   }

instance HasId (State a) where 
   getId = getId . exercisePkg
   changeId f s = s { exercisePkg = changeId f (exercisePkg s) }

stateTerm :: State a -> a
stateTerm = fromMaybe (error "invalid term") . fromContext . stateContext

-----------------------------------------------------------

makeState :: ExercisePackage a -> Maybe (Prefix (Context a)) -> Context a -> State a
makeState = State

empyStateContext :: ExercisePackage a -> Context a -> State a
empyStateContext pkg = makeState pkg (Just pr)
 where
   ex = exercise pkg
   pr = emptyPrefix (strategy ex)

emptyState :: ExercisePackage a -> a -> State a
emptyState pkg = empyStateContext pkg . inContext (exercise pkg)

--------------------------------------------------------------

stateType :: Type a (State a)
stateType = Tag "state" (Iso f g tp)
 where
   f (pkg, mp, ctx) =
      let str = strategy (exercise pkg)
          h   = fromMaybe [] . readM
      in makeState pkg (mp >>= flip makePrefix str . h) ctx
   g st = 
      ( exercisePkg st
      , fmap show (statePrefix st)
      , stateContext st
      )
   tp = tuple3 ExercisePkg prefixType Context

   -- iso prevents that prefix is turned into an (XML) attribute
   prefixType = maybeType (Tag "prefix" (Iso id id String))