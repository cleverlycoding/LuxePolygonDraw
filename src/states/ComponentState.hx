package states;

import luxe.States;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPoly;
import luxe.Input;
import luxe.Color;
import luxe.Vector;
import luxe.collision.Collision;

class ComponentState extends State {
    var main : Main;

    var curEntry : Dynamic;

    //old version
    /*
    var addCollisionBounds : CollisionPoly = new CollisionPoly(0,0,[new Vector(0,0), new Vector(0,0), new Vector(0,0)]);
    var removeComponentCollisionBoxes : Array<CollisionPoly> = [];
    */

    override function init() {
    } //init

    override function onleave<T>( _main:T ) {
    } //onleave

    override function onenter<T>( _main:T ) {
        main = cast(_main, Main);
    } //onenter

    override function update(dt:Float) {

        Luxe.draw.box({
            x : 0,
            y : 0,
            w : 400,
            h : main.uiSceneCamera.size.y,
            batcher : main.uiSceneBatcher,
            immediate : true,
            color : new Color(0,0,0,0.5)
        });

        if (main.curPoly() != null) {

            //get data about selected object
            curEntry = main.componentManager.getEntry(main.curPoly());

            var numComponents = 0;
            if (curEntry != null) {
                numComponents = curEntry.components.length;
            }

            var componentNames = [];
            if (curEntry != null) {
                for (c in cast(curEntry.components, Array<Dynamic>)) {
                    componentNames.push(c.name);
                }
                //trace(componentNames);
            }

            //basic info
            Luxe.draw.text({
                color: new Color(1,1,1),
                pos : new Vector(0,0+20),
                point_size : 16,
                text : "Name: " + main.curPoly().name,
                immediate : true,
                batcher : main.uiSceneBatcher
            });

            Luxe.draw.text({
                color: new Color(1,1,1),
                pos : new Vector(0,16+20),
                point_size : 16,
                text : "Edit component [f]ile",
                immediate : true,
                batcher : main.uiSceneBatcher
            });

            Luxe.draw.text({
                color: new Color(1,1,1),
                pos : new Vector(0,32+20),
                point_size : 16,
                text : "---",
                immediate : true,
                batcher : main.uiSceneBatcher
            });

            Luxe.draw.text({
                color: new Color(1,1,1),
                pos : new Vector(0,48+20),
                point_size : 16,
                text : "Add new [c]omponent",
                immediate : true,
                batcher : main.uiSceneBatcher
            });

            //components
            var i = 0;
            for (cName in componentNames) {
                Luxe.draw.text({
                    color: new Color(1,1,1),
                    pos : new Vector(0, 64 + (i * 16) + 20),
                    point_size : 16,
                    text : cName,
                    immediate : true,
                    batcher : main.uiSceneBatcher
                });

                i++;
            }
        }

        /*
        if (main.curPoly() != null) {

            //get data about selected object
            curEntry = main.componentManager.getEntry(main.curPoly());
        
            var numComponents = 0;
            if (curEntry != null) {
                numComponents = curEntry.components.length;
            }

            var componentNames = [];
            if (curEntry != null) {
                for (c in cast(curEntry.components, Array<Dynamic>)) {
                    componentNames.push(c.name);
                }
                //trace(componentNames);
            }

            //draw component # box
            Luxe.draw.box({
                x : -Luxe.camera.pos.x + main.curPoly().pos.x - 20,
                y : -Luxe.camera.pos.y + main.curPoly().pos.y - 10,
                w : 60,
                h : 30,
                batcher: main.uiBatcher,
                immediate : true,
                color : new Color(255, 255, 255)
            });

            Luxe.draw.rectangle({
                x : -Luxe.camera.pos.x + main.curPoly().pos.x - 20,
                y : -Luxe.camera.pos.y + main.curPoly().pos.y - 10,
                w : 60,
                h : 30,
                batcher: main.uiBatcher,
                immediate : true,
                color : new Color(0, 0, 0)
            });

            Luxe.draw.text({
                color: new Color(0,0,0),
                pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x - 10, 
                    -Luxe.camera.pos.y + main.curPoly().pos.y - 10),
                point_size : 20,
                text : "c: " + numComponents,
                immediate : true,
                batcher : main.uiBatcher
            });

            //draw component box
            var r = main.curPoly().getRectBounds();
            var h = 10 + (numComponents+1) * 20;
            Luxe.draw.box({
                x: -Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20,
                y: -Luxe.camera.pos.y + main.curPoly().pos.y - h/2,
                w : 220,
                h : h,
                immediate : true,
                color : new Color(1,1,1),
                batcher : main.uiBatcher
            });

            //write component names
            var i = 0;
            removeComponentCollisionBoxes = []; //hacky ass way to do this shit <3 <3 <3
            for (cName in componentNames) {
                Luxe.draw.text({
                    color: new Color(0,0,0),
                    pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 40, 
                        -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20)),
                    point_size : 20,
                    text : cName,
                    immediate : true,
                    batcher : main.uiBatcher
                });

                Luxe.draw.text({
                    color: new Color(1,0,0),
                    pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20, 
                        -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20)),
                    point_size : 20,
                    text : "X",
                    immediate : true,
                    batcher : main.uiBatcher
                });

                var x = -Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20;
                var y = -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20);
                var w = 20;
                var h = 20;
                removeComponentCollisionBoxes.push( 
                                        new CollisionPoly(0,0,
                                                [new Vector(x,y), new Vector(x+w,y),
                                                    new Vector(x+w,y+h), new Vector(x,y+h)])); //wtf is this formating le doux <3

                
                i++;
            }

            //add component text
            Luxe.draw.text({
                color: new Color(0,1,0),
                pos : new Vector(-Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20, 
                    -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20)),
                point_size : 20,
                text : "+ Add Component",
                immediate : true,
                batcher : main.uiBatcher
            });

            //update collision box
            var x = -Luxe.camera.pos.x + main.curPoly().pos.x + r.w/2 + 20;
            var y = -Luxe.camera.pos.y + main.curPoly().pos.y - h/2 + (i * 20);
            var w = 200;
            var h = 20;
            addCollisionBounds = new CollisionPoly(0,0,[new Vector(x,y), new Vector(x+w,y),
                                        new Vector(x+w,y+h), new Vector(x,y+h)]);
        }
        */
        
    }

    override function onkeydown(e:KeyEvent) {
        main.selectLayerInput(e);

        main.addSelectedLayerToComponentManagerInput(e);

        //open component file
        if (e.keycode == Key.key_f && Main.instance.curScenePath != null) {
            Sys.command("open '/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl'");
            Sys.command("'/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl' " + 
                Main.instance.curScenePath + "/components/" + main.curPoly().name + ".json");
        }

        if (e.keycode == Key.key_v) {
            machine.set("draw", main);
        }
    }

    override function onmousedown(e:MouseEvent) {
        /*
        if (Collision.pointInPoly(e.pos, addCollisionBounds)) {
            //load
            var rawOpenFileName = Luxe.core.app.io.platform.dialog_open( "Load Component", [{extension:"hx"}] ).split(".");
            var openFileName = rawOpenFileName[0];
            var fileNameSplit = openFileName.split("/"); //need to change for other OSs?
            var className = fileNameSplit[fileNameSplit.length-1];
            main.componentManager.addComponent(main.curPoly(), className);
        }

        for (i in 0 ... removeComponentCollisionBoxes.length) {
            trace("remove comp " + i + "??");

            var rccb = removeComponentCollisionBoxes[i];
            var comp = curEntry.components[i];

            if (Collision.pointInPoly(e.pos, rccb)) {
                trace("kill dat shit");
                curEntry.components.remove(comp);
            }
        }
        */
    }
}