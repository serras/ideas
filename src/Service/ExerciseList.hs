module Service.ExerciseList (exerciseList) where

import Common.Utils (Some(..))
import Common.Exercise
import qualified Domain.LinearAlgebra as LA
import qualified Domain.Logic as Logic
import qualified Domain.RelationAlgebra as RA
import qualified Domain.Derivative.Exercises as Math
import qualified Domain.Fraction as Math

exerciseList :: [Some Exercise]
exerciseList = 
   [ -- linear algebra
     Some LA.reduceMatrixExercise
   , Some LA.solveSystemExercise
   , Some LA.solveSystemWithMatrixExercise
   , Some LA.solveGramSchmidt
     -- basic math
   , Some Math.derivativeExercise
   , Some Math.simplExercise
     -- logic and relation-algebra
   , Some Logic.dnfExercise
   , Some RA.cnfExercise
   ]