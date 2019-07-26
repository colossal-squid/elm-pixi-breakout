port module Main exposing (gameLoopPort, renderUpdatePort)

import Browser
import Html exposing (Html, Attribute, span, div, p, text)
import Html.Attributes exposing (class)
import Keyboard exposing (RawKey)
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)

-- from pixi to Elm
port gameLoopPort: (String -> msg) -> Sub msg
-- from Elm to pixi
port renderUpdatePort: String -> Cmd msg

boardSpeedAcclPx: Float
boardSpeedAcclPx = 12.0

ballAcceleration: Float
ballAcceleration = 10.5

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

-- MODEL
type KeyState = Up | Down

type alias Brick = {
  x: Float,
  y: Float,
  w: Float,
  h: Float}

type alias InitFlags = {
  totalX: Float,
  totalY: Float,
  boardW: Float,
  boardH: Float,
  ballW: Float,
  ballH: Float}

type alias BallState = {
  x: Float,
  y: Float,
  w: Float,
  h: Float,
  acclX: Float,
  acclY: Float}

type alias BoardState = {
  acceleration: Float,
  x: Float,
  y: Float,
  w: Float,
  h: Float}

type alias ControlsState = {
      left: KeyState,
      right: KeyState}

type alias GameState = {
    board: BoardState,
    ball: BallState,
    bricks: List Brick,
    controls: ControlsState,
    field: (Float, Float)}

type alias Model = {
  pressedKeys: List String,
  gameState: GameState}

init : InitFlags -> (Model, Cmd Msg)
init initFlags =
  (Model [] {
      controls = { left = Up, right = Up }
    , ball = {  x = initFlags.totalX / 2
              , y = initFlags.totalY / 2
              , w = initFlags.ballW
              , h = initFlags.ballH
              , acclX = 0
              , acclY = ballAcceleration * -1}
    , board = { acceleration = 0
              , x = initFlags.totalX / 2
              , y = initFlags.totalY * 0.85
              , w = initFlags.boardW
              , h = initFlags.boardH  }
    , field = (initFlags.totalX, initFlags.totalY)
    , bricks = [
       Brick 40 40 80 40
      ,Brick 120 40 80 40
      ,Brick 200 40 80 40
      ,Brick 280 40 80 40
      ,Brick 360 40 80 40
      ,Brick 440 40 80 40
      ,Brick 520 40 80 40
      ,Brick 600 40 80 40

      ,Brick 40 80 80 40
      ,Brick 120 80 80 40
      ,Brick 200 80 80 40
      ,Brick 280 80 80 40
      ,Brick 360 80 80 40
      ,Brick 440 80 80 40
      ,Brick 520 80 80 40
      ,Brick 600 80 80 40
    ]
  }, Cmd.none)


-- ENCODERS
encodeState : GameState -> Value
encodeState state =
  object
    [ 
       ("boardX", float state.board.x)
      ,("ballState", encodeBall state.ball)
      ,("bricksState", encodeBricks state.bricks)
    ]

encodeBall: BallState -> Value
encodeBall ball = object
    [ 
        ("x", float ball.x)
      , ("y", float ball.y)
    ]

encodeBricks: List Brick -> Value
encodeBricks bricks = 
  list (\b -> object [
     ("x", float b.x)
    ,("y", float b.y)
    ,("w", float b.w)
    ,("h", float b.h)
  ]) bricks


-- UPDATE

type Msg = KeyDown RawKey | KeyUp RawKey | GameFrame | ErrorMsg

keysToControls: Model-> RawKey -> KeyState -> ControlsState
keysToControls model rawKey direction =
  case (Keyboard.anyKeyUpper rawKey) of 
    Just key -> case key of 
      (Keyboard.Character a) -> case a of 
        ("A") -> ControlsState direction model.gameState.controls.right
        ("D") -> ControlsState model.gameState.controls.left direction
        _ -> model.gameState.controls
      _ -> model.gameState.controls
    Nothing -> model.gameState.controls

calcBoardAcceleration: ControlsState -> Float -> Float
calcBoardAcceleration keys currentAcceleration = 
  if keys.left == Down then boardSpeedAcclPx * -1
  else if keys.right == Down then boardSpeedAcclPx
  else currentAcceleration

calcBoardAccelerationAfterTick: Float -> Float
calcBoardAccelerationAfterTick currentAccl = 
  if (currentAccl == 0 || Basics.abs currentAccl < 1.001) then 0
  else let sign = currentAccl / Basics.abs currentAccl in (Basics.sqrt (Basics.abs currentAccl)) * sign

calcBallState: BallState -> (Float, Float) -> BoardState -> List Brick -> (BallState, List Brick) 
calcBallState ball (totalX, totalY) board bricks = 
  let newX = ball.x + ball.acclX
      newY = ball.y + ball.acclY
      bounceTreshold = 40
      updatedBall = { ball| x = newX, y = newY }
      bricksToRemove = List.take 1 (List.filter (\b -> rectsIntersect ball.x ball.y ball.w ball.h b.x b.y b.w b.h ) bricks)
      filteredBricks = List.filter (\a -> not (List.member a bricksToRemove) ) bricks
      -- collision with horizontal screen bounds
      in if ((ball.x > totalX - bounceTreshold && ball.acclX > 0)|| 
              (ball.x < bounceTreshold && ball.acclX < 0)) 
          then ({ updatedBall | acclX = updatedBall.acclX * -1 }, bricks)
      -- collision with vertical screen bounds
          else if ((ball.y > totalY - bounceTreshold && ball.acclY > 0)|| 
                    (ball.y < bounceTreshold && ball.acclY < 0))
                  then ({ updatedBall | acclY = updatedBall.acclY * -1 }, bricks)
      -- collision with bricks
          else if List.length bricksToRemove > 0
                  then ({ updatedBall | acclY = updatedBall.acclY * -1 }, filteredBricks)
      -- collision with board
          else if rectsIntersect (ball.x - ball.w/2) (ball.y - ball.h/2) ball.w ball.h (board.x - board.w/2) (board.y - board.h/2) board.w board.h && (ball.acclY > 0)
                  -- only interests me if its the top of the board
                  -- oposite case is eventually gonna kill ya anyway
                  then if ball.y < board.y then 
                    ({ updatedBall | acclY = updatedBall.acclY * -1, acclX = board.acceleration * 1.5 }, bricks)
                  else (updatedBall, bricks)
               else (updatedBall, bricks)

gameLoop: Model -> Model
gameLoop model = 
  let boardAcceleration = calcBoardAcceleration model.gameState.controls model.gameState.board.acceleration
      boardAccelerationAfterTick = calcBoardAccelerationAfterTick boardAcceleration
      (ballState, bricks) = calcBallState model.gameState.ball model.gameState.field model.gameState.board model.gameState.bricks
      board = model.gameState.board
      in (Model [(Debug.toString model.gameState.controls)] {
          controls = model.gameState.controls
        , ball = ballState
        , board = { x = board.x + boardAcceleration
                   ,y = board.y
                   ,acceleration = boardAccelerationAfterTick
                   ,w = board.w
                   ,h = board.h }
        , field = model.gameState.field
        , bricks = bricks
      })

decodeJsMessage: String -> Msg
decodeJsMessage string =
  case string of 
    "GameFrame" -> GameFrame
    _ -> ErrorMsg

encodeJsMessage: Model -> String
encodeJsMessage model = Json.Encode.encode 0 (encodeState model.gameState)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
      KeyDown rawKey -> 
        let game = model.gameState 
            updatedGameState = { game | controls = keysToControls model rawKey Down }
              in ( { model | pressedKeys =  [(Debug.toString game.controls)]
              , gameState = updatedGameState }, Cmd.none )
      KeyUp rawKey -> 
       let game = model.gameState 
           updatedGameState = { game | controls = keysToControls model rawKey Up }
              in ( { model | pressedKeys =  [(Debug.toString game.controls)]
              , gameState = updatedGameState }, Cmd.none )
      GameFrame -> (gameLoop model, renderUpdatePort (encodeJsMessage model))
      ErrorMsg -> (model, Cmd.none) -- i should have visualized it somehow

rectsIntersect: Float -> Float -> Float -> Float -> Float -> Float -> Float -> Float -> Bool
rectsIntersect x1 y1 w1 h1 x2 y2 w2 h2 = 
  x1 < (x2 + w2) && 
  (x1 + w1) > x2 &&
  y1 < (y2 + h2) &&
  (y1 + h1) > y2

-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch [ 
      Keyboard.downs KeyDown
    , Keyboard.ups KeyUp
    , gameLoopPort decodeJsMessage
  ]

-- VIEW

view : Model -> Html Msg
view model =
  p [class "elm-debug"] [
      text("Elm Debug:")
    , p [ ] [text( "Keys pressed: " ++ Debug.toString model.pressedKeys)]
    , p [ ] [text( "Ball: " ++ Debug.toString model.gameState.ball)]
    , p [ ] [text( "Board: " ++ Debug.toString model.gameState.board)]
    , p [ ] [text( "Bricks: (" ++ Debug.toString (List.length model.gameState.bricks) ++ ") " ++ Debug.toString model.gameState.bricks)]

  ]