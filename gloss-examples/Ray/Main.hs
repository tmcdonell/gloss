{-# LANGUAGE BangPatterns #-}
import World
import Trace
import Light
import Object
import Vec3
import System.Environment
import qualified Graphics.Gloss                 as G
import qualified Graphics.Gloss.Interface.Game  as G
import qualified Graphics.Gloss.Field           as G


main :: IO ()
main 
 = do   args    <- getArgs
        case args of
         []     -> run 720 450 2 400

         [sizeX, sizeY, zoom, fov]
                -> run (read sizeX) (read sizeY) (read zoom) (read fov)

         _ -> putStr $ unlines
           [ "trace <sizeX::Int> <sizeY::Int> <zoom::Int> (fov::Int)"
           , "    sizeX, sizeY - visualisation size        (default 720, 450)"
           , "    zoom         - pixel replication factor  (default 2)"
           , "    fov          - field of view             (default 400)"
           , ""
           , " You'll want to run this with +RTS -N to enable threads" ]
   

-- | World and interface state.
data State
        = State
        { stateTime             :: Float 
        , stateEyePos           :: Vec3
        , stateEyeLoc           :: Vec3

        , stateLeftClick        :: Maybe G.Point 

        , stateObjects          :: [Object]
        , stateObjectsView      :: [Object]

        , stateLights           :: [Light]
        , stateLightsView       :: [Light] }

        deriving (Eq, Show)


-- | Initial world and interface state.
initState :: State
initState
        = State
        { stateTime             = 0
        , stateEyePos           = Vec3 50 (-100) (-500)
        , stateEyeLoc           = Vec3 0 0 0
        , stateLeftClick        = Nothing 

        , stateObjects          = makeObjects 0
        , stateObjectsView      = makeObjects 0

        , stateLights           = makeLights  0
        , stateLightsView       = makeLights  0 }


-- | Run the game.
run :: Int -> Int -> Int -> Int -> IO ()                     
run sizeX sizeY zoom fov 
 = G.playField 
        (G.InWindow "ray" (sizeX, sizeY) (100, 100)) 
        (zoom, zoom)
        100
        initState
        (tracePixel sizeX sizeY fov)
        handleEvent
        advanceState


-- | Render a single pixel of the image.
tracePixel :: Int -> Int -> Int -> State -> G.Point -> G.Color
tracePixel !sizeX !sizeY !fov !state (x, y)
 = let  sizeX'  = fromIntegral sizeX
        sizeY'  = fromIntegral sizeY
        aspect  = sizeX' / sizeY'
        fov'    = fromIntegral fov
        fovX    = fov' * aspect
        fovY    = fov'
       
        ambient = Vec3 0.3 0.3 0.3
        eyePos  = stateEyePos state
        eyeDir  = normaliseV3 ((Vec3 (x * fovX) ((-y) * fovY) 0) - eyePos)

        Vec3 r g b
          = traceRay    (stateObjectsView state) 
                        (stateLightsView  state) ambient
                        eyePos eyeDir
                        8               -- max bounces.

   in   G.rawColor r g b 1.0
{-# INLINE tracePixel #-}


-- | Handle an event from the user interface.
handleEvent :: G.Event -> State -> State
handleEvent event state 
        -- Start translation.
        | G.EventKey (G.MouseButton G.LeftButton) 
                     G.Down _ (x, y) <- event
        = state { stateLeftClick = Just (x, y)}

        -- End transation.
        | G.EventKey _ G.Up _ _ <- event
        = state { stateLeftClick = Nothing }

        -- Translate the world.
        | G.EventMotion (x, y)  <- event
        , Just (oX, oY)         <- stateLeftClick state
        , Vec3 eyeX eyeY eyeZ   <- stateEyeLoc    state
        = let   eyeX'   = eyeX + (x - oX)
                eyeY'   = eyeY
                eyeZ'   = eyeZ + (y - oY)

          in    setEyeLoc (Vec3 eyeX' eyeY' eyeZ')
                 $ state { stateLeftClick  = Just (x, y) }
        
        | otherwise
        = state


-- | Advance the world forward in time.
advanceState :: Float -> State -> State
advanceState advTime state
 = let  time'   = stateTime state + advTime
   in   setTime time' state


-- | Set the location of the eye.
setEyeLoc :: Vec3 -> State -> State
setEyeLoc eyeLoc state
 = let  objects = makeObjects (stateTime state)
        lights  = makeLights  (stateTime state)
   in state 
        { stateEyeLoc           = eyeLoc
        , stateObjectsView      = map (translateObject (stateEyeLoc state)) objects
        , stateLightsView       = map (translateLight  (stateEyeLoc state)) lights 
        }


-- | Set the time of the world.
setTime   :: Float -> State -> State
setTime time state
 = let  objects = makeObjects time
        lights  = makeLights  time
   in state 
        { stateTime             = time
        , stateObjects          = objects
        , stateObjectsView      = map (translateObject (stateEyeLoc state)) objects

        , stateLights           = lights
        , stateLightsView       = map (translateLight  (stateEyeLoc state)) lights 
        }
