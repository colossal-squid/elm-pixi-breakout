import * as Rx from 'rxjs'
import * as PIXI from 'pixi.js'
import { Elm } from './elm-main'

(function () {

    let board, elmApp;

    function gameLoop () {
        elmApp.ports.gameLoopPort.send("GameFrame");
    }

    function component() {
        const app = new PIXI.Application();
        // load the texture we need
        app.loader.add('board', 'images/board.png').load((loader, resources) => initializeSprite(app, resources));
        return app.view;
    }
    
    function elmComponent() {
        const element = document.getElementById('elm');
    
        if (!element) {
            throw new Error('Elm element was not found in DOM');
        }
    
        elmApp = Elm.Main.init({
            node: element
        });
    }
    
    function initializeSprite(app, resources) {
        const elmZeroX = app.renderer.width / 2;
    
        board = new PIXI.Sprite(resources.board.texture);
        board.x = elmZeroX;
        board.y = app.renderer.height * 0.85;
    
        board.anchor.x = 0.5;
        board.anchor.y = 0.5;
    
        app.stage.addChild(board);
    
        app.ticker.add(() => gameLoop());
        elmApp.ports.renderUpdatePort.subscribe(function (data) {
            // OX: 0 in Elm is app.renderer.width / 2 in renderer, so X == 0 is center of the screen
            const dX = elmZeroX + Number(data);
            board.x = dX;
        });
    }
    
    elmComponent()
    document.body.appendChild(component());
} ())