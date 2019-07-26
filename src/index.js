import * as Rx from 'rxjs'
import * as PIXI from 'pixi.js'
import { Elm } from './elm-main'

(async function () {
    // init pixi side of things first
    const {pixiApp, board, ball} = await initPixiApp();

    // init the ELM part of the game
    let elmApp = createElmApp('#elm', {
        totalX: pixiApp.renderer.width,
        totalY: pixiApp.renderer.height,
        boardW: board.width,
        boardH: board.height,
        ballW: ball.width,
        ballH: ball.height
    });

    pixiApp.ticker.add(() => {
        // PIXI calls this for every game frame
        elmApp.ports.gameLoopPort.send("GameFrame");
    });

    function initPixiApp() {
        return new Promise((resolve, reject) => {
            const app = new PIXI.Application(),
            centerOx = app.renderer.width / 2;

            // load the textures
            app.loader
              .add('board', 'images/board.png')
              .add('ball', 'images/ball.png')
              .load((loader, resources) => {
                  const boardSprite = new PIXI.Sprite(resources.board.texture);
  
                  boardSprite.x = centerOx;
                  boardSprite.y = app.renderer.height * 0.85;
  
                  boardSprite.anchor.x = 0.5;
                  boardSprite.anchor.y = 0.5;

                  const ballSprite = new PIXI.Sprite(resources.ball.texture);
                  ballSprite.anchor.x = 0.5;
                  ballSprite.anchor.y = 0.5;

                  ballSprite.x = centerOx;
                  ballSprite.y = app.renderer.height/2;

                  ballSprite.width = 48;
                  ballSprite.height = 48;

                  app.stage.addChild(boardSprite);
                  app.stage.addChild(ballSprite);

                  resolve({pixiApp: app, board: boardSprite, ball: ballSprite });
              });
        })
    }

    function createElmApp(selector, flags) {
        const elmElement = document.querySelector(selector);

        if (!elmElement) {
            throw new Error(`Elm element (${selector}) was not found in DOM`);
        }

        const elmApp =  Elm.Main.init({ 
            node: elmElement,
            flags
        });
        elmApp.ports.renderUpdatePort.subscribe((data) => render(data) );
        return elmApp;
    }

    // This function is a callback from Elm's game loop into pixi
    function render(data) {
        let [boardX, ballX, ballY] = data.split(',')
        board.x = Number(boardX);
        ball.x = Number(ballX);
        ball.y = Number(ballY);
    }

    document.body.appendChild(pixiApp.view);
} ())