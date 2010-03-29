-----------------------------------------------------------------------------
-- Copyright 2009, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.Polynomial.IneqExercises 
   ( ineqLinearExercise, ineqQuadraticExercise, ineqHigherDegreeExercise
   ) where

import Common.Context
import Common.Exercise
import Common.Strategy hiding (not)
import Common.Transformation
import Common.Uniplate (uniplate)
import Common.View
import Control.Monad
import Data.List (nub, sort)
import Data.Maybe (fromMaybe)
import Domain.Math.Data.Interval
import Domain.Logic.Formula (Logic((:||:), (:&&:)))
import Domain.Math.Clipboard
import Domain.Math.Data.OrList
import Domain.Math.Data.Relation
import Domain.Math.Equation.CoverUpRules hiding (coverUpPlus)
import Domain.Math.Polynomial.Exercises (eqRelation, normRelation)
import Domain.Math.Equation.Views
import Domain.Math.Examples.DWO2
import Domain.Math.Expr
import Domain.Math.Numeric.Views
import Domain.Math.Polynomial.CleanUp
import Domain.Math.Polynomial.Rules 
import Domain.Math.Polynomial.Strategies
import Domain.Math.Polynomial.Equivalence
import Domain.Math.SquareRoot.Views
import Prelude hiding (repeat)
import qualified Domain.Logic.Formula as Logic

ineqLinearExercise :: Exercise (Relation Expr)
ineqLinearExercise = makeExercise 
   { description  = "solve a linear inequation"
   , exerciseCode = makeCode "math" "linineq"
   , status       = Provisional
   , parser       = parseExprWith (pRelation pExpr)
   , isReady      = solvedRelation
   , equivalence  = linEq
   , similarity   = eqRelation cleanUpExpr2
   , strategy     = mapRules liftToContext ineqLinear
   , examples     = let x = Var "x"
                        extra = (x-12) / (-2) :>: (x+3)/3
                    in map (build inequalityView) (concat ineqLin1 ++ [extra])
   } 
   
ineqQuadraticExercise :: Exercise (Logic (Relation Expr))
ineqQuadraticExercise = makeExercise 
   { description   = "solve a quadratic inequation"
   , exerciseCode  = makeCode "math" "quadrineq"
   , status        = Provisional
   , parser        = parseExprWith (pLogicRelation pExpr)
   , prettyPrinter = showLogicRelation
   , isReady       = solvedRelations
   , eqWithContext = Just quadrEqContext
   , similarity    = simLogic (normRelation cleanUpExpr2 . flipGT)
   , strategy      = ineqQuadratic
   , examples      = map (Logic.Var . build inequalityView) 
                         (concat $ ineqQuad1 ++ [ineqQuad2, extraIneqQuad])
   }

ineqHigherDegreeExercise :: Exercise (Logic (Relation Expr))
ineqHigherDegreeExercise = makeExercise 
   { description   = "solve an inequation of higher degree"
   , exerciseCode  = makeCode "math" "ineqhigherdegree"
   , status        = Provisional
   , parser        = parseExprWith (pLogicRelation pExpr)
   , prettyPrinter = showLogicRelation
   , isReady       = solvedRelations
   , eqWithContext = Just highEqContext
   , similarity    = simLogic (normRelation cleanUpExpr2 . flipGT)
   , strategy      = ineqHigherDegree
   , examples      = map (Logic.Var . build inequalityView) ineqHigh
   }

showLogicRelation :: (Eq a, Show a) => Logic (Relation a) -> String
showLogicRelation logic = 
   case logic of
      Logic.T     -> "true"
      Logic.F     -> "false"
      Logic.Var a -> show a
      p :||: q    -> showLogicRelation p ++ " or " ++ showLogicRelation q
      p :&&: q    -> case match betweenView logic of
                        Just (x, o1, y, o2, z) -> 
                           let f b = if b then "<=" else "<"
                           in unwords [show x, f o1, show y, f o2, show z]
                        _ -> showLogicRelation p ++ " and " ++ showLogicRelation q
      _           -> show logic

betweenView :: Eq a => View (Logic (Relation a)) (a, Bool, a, Bool, a)
betweenView = makeView f h
 where
   f (Logic.Var r1 :&&: Logic.Var r2) = do
      ineq1 <- match inequalityView r1
      ineq2 <- match inequalityView r2
      let g (a :>=: b) = b :<=: a
          g (a :>:  b) = b :<:  a
          g ineq       = ineq
      make (g ineq1) (g ineq2)
   f _ = Nothing
   
   make a b
      | la == rb && ra /= lb = make b a
      | ra == lb =
           Just (la, op a, ra, op b, rb)
      | otherwise = Nothing
    where
      (la, ra) = (leftHandSide a, rightHandSide a)
      (lb, rb) = (leftHandSide b, rightHandSide b)
      op (_ :<=: _) = True
      op _          = False
   
   h (x, o1, y, o2, z) = 
      let f b = if b then (.<=.) else (.<.)
      in Logic.Var (f o1 x y) :&&: Logic.Var (f o2 y z)


ineqLinear :: LabeledStrategy (Relation Expr)
ineqLinear = cleanUpStrategy (fmap cleanUpSimple) $
   label "Linear inequation" $
      label "Phase 1" (repeat (
             removeDivision
         <|> ruleMulti (ruleSomewhere distributeTimes)
         <|> ruleMulti merge))
      <*>  
      label "Phase 2" (
         try varToLeft 
         <*> try (coverUpPlus id)
         <*> try flipSign
         <*> try coverUpTimesPositive)

-- helper strategy
coverUpPlus :: (Rule (Relation Expr) -> Rule a) -> Strategy a
coverUpPlus f = alternatives $ map (f . ($ oneVar))
   [ coverUpBinaryRule "plus" (commOp . isPlus) (-) 
   , coverUpBinaryRule "minus left" isMinus (+)
   , coverUpBinaryRule "minus right" (flipOp . isMinus) (flip (-))
   ] -- [coverUpPlusWith, coverUpMinusLeftWith, coverUpMinusRightWith]
   
coverUpTimesPositive :: Rule (Relation Expr)
coverUpTimesPositive = coverUpBinaryRule "times positive" (commOp . m) (/) varConfig
 where
   m expr = do
      (a, b) <- matchM timesView expr
      r <- matchM rationalView a
      guard (r>0)
      return (a, b)
      
flipSign :: Rule (Relation Expr)
flipSign = makeSimpleRule "flip sign" $ \r -> do
   let lhs = leftHandSide r
       rhs = rightHandSide r
   guard (isNegative lhs) 
   return $ constructor (flipSides r) (neg lhs) (neg rhs)
 where
   isNegative (Negate _) = True
   isNegative expr = 
      maybe False fst (match productView expr)
 
ineqQuadratic :: LabeledStrategy (Context (Logic (Relation Expr)))
ineqQuadratic = label "Quadratic inequality" $ 
   try (liftRule (contextView (orView >>> justOneView)) turnIntoEquation) 
   <*> mapRules (liftRule (contextView orView)) quadraticStrategy
   <*> solutionInequation

ineqHigherDegree :: LabeledStrategy (Context (Logic (Relation Expr)))
ineqHigherDegree = label "Inequality of a higher degree" $ 
   try (liftRule (contextView (orView >>> justOneView)) turnIntoEquation) 
   <*> mapRules (liftRule (contextView orView)) higherDegreeStrategy
   <*> solutionInequation

justOneView :: View (OrList a) a
justOneView = makeView (f . disjunctions) return
 where
   f (Just [r]) = Just r
   f _          = Nothing

turnIntoEquation :: Rule (Context (Relation Expr))
turnIntoEquation = makeSimpleRule "turn into equation" $ withCM $ \r -> do
   guard (relationType r `elem` ineqTypes)
   addToClipboard "ineq" (toExpr r)
   return (leftHandSide r .==. rightHandSide r)
 where
   ineqTypes = 
      [LessThan, GreaterThan, LessThanOrEqualTo, GreaterThanOrEqualTo]

-- Todo: cleanup this function
solutionInequation :: Rule (Context (Logic (Relation Expr)))
solutionInequation = makeSimpleRule "solution inequation" $ withCM $ \r -> do
   ineq <- lookupClipboard "ineq" >>= fromExpr
   removeClipboard "ineq"
   orv  <- maybeCM (matchM orView r)
   case disjunctions orv of 
      Nothing -> -- both sides are the same
         if relationType ineq `elem` [GreaterThanOrEqualTo, LessThanOrEqualTo]
         then return Logic.T
         else return Logic.F
      Just [] -> do -- no solutions found for equations
         let vs = collectVars (toExpr ineq)
         guard (not (null vs))
         if evalIneq ineq (head vs) 0
            then return Logic.T 
            else return Logic.F
      Just xs -> do
         (vs, ys) <- liftM unzip $ matchM (listView (equationView >>> equationSolvedForm)) xs
         let v  = head vs
             zs = nub $ map (simplify (squareRootViewWith rationalView)) ys
         ds <- matchM (listView doubleView) zs
         guard (all (==v) vs)
         let rs = makeRanges including (sort (zipWith A ds zs))
             including = relationType ineq `elem` [GreaterThanOrEqualTo, LessThanOrEqualTo]
         return $ fromIntervals v fromDExpr $ 
            fromList [ this | (d, isP, this) <- rs, isP || evalIneq ineq v d ]
 where
   makeRanges :: Bool -> [DExpr] -> [(Double, Bool, Interval DExpr)]
   makeRanges b xs =
      [makeLeft $ head xs]
      ++ concatMap (uncurry makeMiddle) (zip xs (drop 1 xs))
      ++ [makePoint (last xs) | b]
      ++ [makeRight $ last xs]
    where
      makeLeft  a@(A d _)
         | b         = (d-1, False, lessThanOrEqualTo a)
         | otherwise = (d-1, False, lessThan a)
      makeRight a@(A d _)
         | b         = (d+1, False, greaterThanOrEqualTo a)
         | otherwise = (d+1, False, greaterThan a)
      makePoint a@(A d _) = (d, True, singleton a)
      makeMiddle a1@(A d1 _) a2@(A d2 _) =
         [ makePoint a1 | b ] ++
         [ ( (d1+d2)/2
           , False
           , open a1 a2
           )
         ]
      
   evalIneq :: Relation Expr -> String -> Double -> Bool
   evalIneq r v d = fromMaybe False $
      liftM2 (evalType (relationType r)) (use leftHandSide) (use rightHandSide)
    where
      use f = match doubleView (sub (f r))
      
      evalType tp =
         case tp of 
            EqualTo              -> (==)
            NotEqualTo           -> (/=)
            LessThan             -> (<)
            GreaterThan          -> (>)
            LessThanOrEqualTo    -> (<=)
            GreaterThanOrEqualTo -> (>=)
            Approximately        -> \a b -> abs (a-b) < 0.001
      
      sub (Var x) | x==v = Number d
      sub expr = build (map sub cs)
       where (cs, build) = uniplate expr

data DExpr = A Double Expr

instance Eq DExpr where 
   A d1 _ == A d2 _ = d1==d2

instance Ord DExpr where
   A d1 _ `compare` A d2 _ = d1 `compare` d2

fromDExpr :: DExpr -> Expr
fromDExpr (A _ e) = e
  
fromIntervals :: Eq a => String -> (a -> Expr) -> Intervals a -> Logic (Relation Expr)
fromIntervals v f = ors . map (fromInterval v f) . toList
 where
   ors [] = Logic.F
   ors xs = foldr1 (:||:) xs
   
fromInterval :: Eq a => String -> (a -> Expr) -> Interval a -> Logic (Relation Expr)
fromInterval v f i 
   | isEmpty i = Logic.F
   | otherwise = 
        case (leftPoint i, rightPoint i) of
           (Unbounded, Unbounded) -> Logic.T
           (Unbounded, Including b) -> Logic.Var (Var v .<=. f b)
           (Unbounded, Excluding b) -> Logic.Var (Var v .<. f b)
           (Including a, Unbounded) -> Logic.Var (Var v .>=. f a)
           (Excluding a, Unbounded) -> Logic.Var (Var v .>. f a)
           (Including a, Including b) 
              | a == b    -> Logic.Var (Var v .==. f a)
              | otherwise -> Logic.Var (Var v .>=. f a) :&&: Logic.Var (Var v .<=. f b) 
           (Including a, Excluding b) -> Logic.Var (Var v .>=. f a) :&&: Logic.Var (Var v .<. f b) 
           (Excluding a, Including b) -> Logic.Var (Var v .>. f a) :&&: Logic.Var (Var v .<=. f b) 
           (Excluding a, Excluding b) -> Logic.Var (Var v .>. f a) :&&: Logic.Var (Var v .<. f b) 