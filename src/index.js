import * as PIXI from 'pixi.js'

function component() {
    const app = new PIXI.Application();
    // load the texture we need

    app.loader.add('board', 'images/board.png').load((loader, resources) => initializeSprite(app, resources));

    return app.view;
}

function initializeSprite(app, resources) {
 
    const board = new PIXI.Sprite(resources.board.texture);
 
    board.x = app.renderer.width / 2;
    board.y = app.renderer.height / 2;
 
    board.anchor.x = 0.5;
    board.anchor.y = 0.5;

    app.stage.addChild(board);

    app.ticker.add(() => {
         // each frame we spin the bunny around a bit
         board.rotation += 0.01;
    });
}

  document.body.appendChild(component());