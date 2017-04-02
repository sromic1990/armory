package armory.logicnode;

class SetVisibleNode extends Node {

	public function new(trait:armory.Trait) {
		super(trait);
	}

	override function run() {
		var object = inputs[1].get();
		var visible = inputs[2].get();
		
		if (object == null) object = trait.object;

		object.visible = visible;

		super.run();
	}
}
