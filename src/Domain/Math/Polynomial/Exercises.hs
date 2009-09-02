module Domain.Math.Polynomial.Exercises where

import Domain.Math.Polynomial.LinearEquations
import Domain.Math.Polynomial.QuadraticEquations
import Domain.Math.Polynomial.HigherDegreeEquations
import Domain.Math.Polynomial.Views
import Common.Exercise
import Domain.Math.Data.Equation
import Domain.Math.Equation.Views
import Domain.Math.Expr
import Domain.Math.Data.OrList
import Domain.Math.ExercisesDWO
import Domain.Math.Expr.Parser
import Common.View
import Common.Context

------------------------------------------------------------
-- Exercises

linearExercise :: Exercise (Equation Expr)
linearExercise = makeExercise 
   { identifier    = "lineq"
   , domain        = "math"
   , description   = "solve a linear equation"
   , status        = Experimental
   , parser        = parseWith (pEquation pExpr)
   , equality      = (==)
   , equivalence   = viewEquivalent linearEquationView
   , finalProperty = solvedEquation
   , ruleset       = linearRules
   , strategy      = ignoreContext linearStrategy
   , termGenerator = ExerciseList (concat linearEquations)
   }

quadraticExercise :: Exercise (OrList (Equation Expr))
quadraticExercise = makeExercise 
   { identifier    = "quadreq"
   , domain        = "math"
   , description   = "solve a quadratic equation"
   , status        = Experimental
   , parser        = parseWith (pOrList (pEquation pExpr))
   , equality      = (==) 
   , equivalence   = viewEquivalent quadraticEquationsView
   , finalProperty = solvedList
   , ruleset       = map ignoreContext quadraticRules
   , strategy      = ignoreContext quadraticStrategy
   , termGenerator = ExerciseList (map (OrList . return) $ concat quadraticEquations)
   }
   
higherDegreeExercise :: Exercise (OrList (Equation Expr))
higherDegreeExercise = makeExercise 
   { identifier    = "higherdegree"
   , domain        = "math"
   , description   = "solve an equation (higher degree)"
   , status        = Experimental
   , parser        = parseWith (pOrList (pEquation pExpr))
   , equality      = (==) 
   , equivalence   = eqHD
   , finalProperty = solvedList
   , ruleset       = map ignoreContext higherDegreeRules
   , strategy      = ignoreContext higherDegreeStrategy
   , termGenerator = ExerciseList (map (OrList . return) higherDegreeEquations)
   }

   
   {-
main :: IO ()
main = printDerivations linearEquationExercise (concat linearEquations)


testAll = drop 0 $ zipWith f [1..] (concat quadraticEquations)
 where
   f i e
      | not (solvedList (solve e)) = 
           error (show e ++ "  becomes   " ++ show (solve e))
      | testD e   = 0
      | otherwise = i

testD :: Equation Expr -> Bool
testD e = 
   case derivations (unlabel solverQ) (OrList [e]) of
      [] -> error "no derivation"
      (a, ps):_ -> 
         let xs = a : map snd ps
         in case [ (x, y) | x <- xs, y <- xs, not (equivalence quadraticEquationExercise x y) ] of
               []   -> False
               (x,y):_ -> error $ show (x, y, match qView x, match qView y) -- (simplify qView x) ++ "    is not    " ++ show (simplify qView y)

main :: IO ()
main = printDerivations quadraticEquationExercise xs 
 where xs = map (OrList . return) (concat quadraticEquations)

main :: IO ()
main = printDerivations higherDegreeEquationExercise xs 
 where xs = map (OrList . return) higherDegreeEquations
-}