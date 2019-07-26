import * as Rx from 'rxjs'
import * as PIXI from 'pixi.js'
import { Elm } from './elm-main'

(async function () {
    // init pixi side of things first
    const { pixiApp, board, ball } = await initPixiApp();
    let bricks = [];
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
                .add('brick', 'images/brick.png')
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
                    ballSprite.y = app.renderer.height / 2;

                    ballSprite.width = 24;
                    ballSprite.height = 24;

                    app.stage.addChild(boardSprite);
                    app.stage.addChild(ballSprite);

                    resolve({ pixiApp: app, board: boardSprite, ball: ballSprite });
                });
        })
    }

    function createElmApp(selector, flags) {
        const elmElement = document.querySelector(selector);

        if (!elmElement) {
            throw new Error(`Elm element (${selector}) was not found in DOM`);
        }

        const elmApp = Elm.Main.init({
            node: elmElement,
            flags
        });
        elmApp.ports.renderUpdatePort.subscribe((data) => render(data));
        return elmApp;
    }

    // This function is a callback from Elm's game loop into pixi
    function render(data) {
        let { boardX, ballState, bricksState } = JSON.parse(data);
        board.x = boardX;
        ball.x = ballState.x;
        ball.y = ballState.y;

        if (!bricks.length) {
            // init
            bricksState.forEach(b => {
                const sprite = new PIXI.Sprite(pixiApp.loader.resources.brick.texture);
                sprite.x = b.x;
                sprite.y = b.y;
                sprite.width = b.w;
                sprite.height = b.h;

                pixiApp.stage.addChild(sprite);
                bricks.push(sprite);
            })
        } else {
            bricks = bricks.filter(b => {
                const stillPresent = bricksState.find(bs => bs.x == b.x && bs.y == b.y);
                if (!stillPresent) {
                    pixiApp.stage.removeChild(b)
                }
                return stillPresent;
            })
        }
    }

    document.body.appendChild(pixiApp.view);
}())