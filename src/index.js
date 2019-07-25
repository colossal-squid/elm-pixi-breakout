import * as Rx from 'rxjs'
import * as PIXI from 'pixi.js'
import { Elm } from './elm-main'

(async function () {
    // init pixi side of things first
    const {pixiApp, board, elmZeroX} = await initPixiApp();
    // init the ELM part of the game
    let elmApp = createElmApp('#elm');
    pixiApp.ticker.add(() => {
        // PIXI calls this for every game frame
        elmApp.ports.gameLoopPort.send("GameFrame");
    });

    function initPixiApp() {
        return new Promise((resolve, reject) => {
            const app = new PIXI.Application(),
            elmZeroX = app.renderer.width / 2;

            // load the textures
            app.loader.add('board', 'images/board.png').load((loader, resources) => {
                const boardSprite = new PIXI.Sprite(resources.board.texture);

                boardSprite.x = elmZeroX;
                boardSprite.y = app.renderer.height * 0.85;

                boardSprite.anchor.x = 0.5;
                boardSprite.anchor.y = 0.5;
                app.stage.addChild(boardSprite);
                resolve({pixiApp: app, board: boardSprite, elmZeroX: elmZeroX });
            });
        })
    }

    function createElmApp(selector) {
        const elmElement = document.querySelector(selector);

        if (!elmElement) {
            throw new Error(`Elm element (${selector}) was not found in DOM`);
        }

        const elmApp =  Elm.Main.init({ node: elmElement});
        elmApp.ports.renderUpdatePort.subscribe((data) => render(data) );
        return elmApp;
    }

    // This function is a callback from Elm's game loop into pixi
    function render(data) {
        // OX: 0 in Elm is app.renderer.width / 2 in renderer, so X == 0 is center of the screen
        const dX = elmZeroX + Number(data);
        board.x = dX;
    }

    document.body.appendChild(pixiApp.view);
} ())