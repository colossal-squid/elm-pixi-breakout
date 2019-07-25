port module Main exposing (gameLoopPort, renderUpdatePort)

import Browser
import Html exposing (Html, Attribute, span, div, p, text)
import Html.Attributes exposing (class)
import Keyboard exposing (RawKey)
import Json.Encode as E

-- from pixi to Elm
port gameLoopPort: (String -> msg) -> Sub msg
-- from Elm to pixi
port renderUpdatePort: String -> Cmd msg

boardSpeedAcclPx: Float
boardSpeedAcclPx = 12.0

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }


-- MODEL
type KeyState = Up | Down

type alias BoardState = {
  acceleration: Float,
  x: Float}

type alias ControlsState = {
      left: KeyState,
      right: KeyState}

type alias GameState = {
    board: BoardState,
    controls: ControlsState}

type alias Model = {
  pressedKeys: List String,
  gameState: GameState}

init : () -> (Model, Cmd Msg)
init _ =
  (Model [] {
    controls = { left = Up, right = Up },
    board = { acceleration = 0, x = 0  }
  }, Cmd.none)


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

gameLoop: Model -> Model
gameLoop model = 
  let boardAcceleration = calcBoardAcceleration model.gameState.controls model.gameState.board.acceleration
      boardAccelerationAfterTick = calcBoardAccelerationAfterTick boardAcceleration
      board = model.gameState.board
      in (Model [(Debug.toString model.gameState.controls)] {
        controls = model.gameState.controls,
        board = { x = board.x + boardAcceleration, acceleration = boardAccelerationAfterTick }
      })

decodeJsMessage: String -> Msg
decodeJsMessage string =
  case string of 
    "GameFrame" -> GameFrame
    _ -> ErrorMsg


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
      GameFrame -> (gameLoop model, renderUpdatePort (Debug.toString model.gameState.board.x))
      ErrorMsg -> (model, Cmd.none) -- i should have visualized it somehow

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
  ]

-- PORTS