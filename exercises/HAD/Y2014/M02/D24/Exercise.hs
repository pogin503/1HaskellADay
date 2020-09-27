module HAD.Y2014.M02.D24.Exercise where
-- | Filter a list, keeping an element only if it is equal to the next one.
--
-- Examples:
-- >>> filterByPair []
-- []
-- >>> filterByPair [1 .. 10]
-- []
-- >>> filterByPair [1, 2, 2, 2, 3, 3, 4]
-- [2,2,3]

--filterByPair :: Find the most generic signature
-- OK
filterByPair :: Eq a => [a] -> [a]
filterByPair xs =
  f xs
  where
    f [] = []
    f [_] = []
    f (x:y:xs') = if x == y
                 then x : f (y:xs')
                 else f (y:xs')

-- TODO
-- filterByPair' :: Eq a => [a] -> [a]
-- filterByPair' xs =
--   f xs
--   where
--     f xs'
--       | xs' == [] = []
--       | length xs' == 1 = xs'
--       | otherwise = if xs' !! 0 == xs' !! 1
--                     then xs' !! 0 : f (tail xs')
--                     else f (tail xs')
