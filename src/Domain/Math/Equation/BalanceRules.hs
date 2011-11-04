-----------------------------------------------------------------------------
-- Copyright 2011, Open Universiteit Nederland. This file is distributed
-- under the terms of the GNU General Public License. For more information,
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.Equation.BalanceRules
   ( plusT, minusT, timesT, divisionT
   ) where

import Common.Transformation
import Common.View
import Control.Monad
import Domain.Math.Data.Relation
import Domain.Math.Expr
import Domain.Math.Numeric.Views

plusT, minusT :: Functor f => Expr -> Transformation (f Expr)
plusT  e = makeTrans $ Just . fmap (:+: e)
minusT e = makeTrans $ Just . fmap (:-: e)

timesT :: Functor f => Expr -> Transformation (f Expr)
timesT e = makeTrans $ unlessZero e . fmap (e :*:)

divisionT :: Expr -> Transformation (Equation Expr)
divisionT e = makeTrans $ unlessZero e . fmap (:/: e)

unlessZero :: Expr -> a -> Maybe a
unlessZero e a = do
   r <- matchM rationalView e
   guard (r /= 0)
   return a