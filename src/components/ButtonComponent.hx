package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;
import luxe.Vector;
import luxe.Color;
import luxe.collision.Collision;
import luxe.collision.shapes.Circle in CollisionCircle;
import luxe.collision.shapes.Polygon in CollisionPoly;
import luxe.Input.MouseEvent;

class ButtonComponent extends EditorComponent {

	var polygon : Polygon;

	public var isActive : Bool;

	@editor
	public var componentsToActivate : Array<String>;

	@editor
	public var buttonGroup : Array<String>;

	@editor({r:1, g:1, b:1})
	public var inactiveColor : Dynamic;
	@editor({r:1, g:0, b:0})
	public var activeColor : Dynamic;

	@editor(false)
	public var isSwitch : Bool; //stays active until pressed again

	override function init() {
		polygon = cast entity;
		isActive = false;

		trace(inactiveColor.r);
	}

	override function update(dt : Float) {
		//trace("button active " + isActive);
	}

	override function onremoved() {
	}

	override function onmousedown(e : MouseEvent) {

		if ( Collision.pointInPoly(e.pos, polygon.getRectCollisionBounds()) ) {
			isActive = !isActive;
			isActive ? activate() : deactivate();
		}
	}

	override function onmouseup(e : MouseEvent) {
		if (!isSwitch) {
			isActive = false;
			deactivate();
		}
	}

	function activate() {
		for (c in polygon.children) {
			var p = cast(c, Polygon);

			if (p.geometry.color.r == inactiveColor.r &&
				p.geometry.color.g == inactiveColor.g &&
				p.geometry.color.b == inactiveColor.b) {

					p.geometry.color = new Color(activeColor.r, activeColor.g, activeColor.b);

			}
		}

		for (componentName in componentsToActivate) {
			cast(polygon.components.get(componentName), ActivateableComponent).activate();
		}
	}

	function deactivate() {
		for (c in polygon.children) {
			var p = cast(c, Polygon);

			if (p.geometry.color.r == activeColor.r &&
				p.geometry.color.g == activeColor.g &&
				p.geometry.color.b == activeColor.b) {

					p.geometry.color = new Color(inactiveColor.r, inactiveColor.g, inactiveColor.b);
			}
		}
	}
}