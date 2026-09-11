package funkin.play.stage;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.FlxTrail;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import haxe.Json;

typedef StageAnimData =
{
	var name:String;
	var anim:String;
	var fps:Int;
	var ?loop:Bool;
	var ?indices:Array<Int>;
}

typedef StageSpriteData =
{
	var name:String;
	var x:Float;
	var y:Float;
	var ?image:String;
	var ?library:String;
	var ?atlasType:String;
	var ?scrollFactor:Array<Float>;
	var ?scale:Float;
	var ?antialiasing:Bool;
	var ?visible:Bool;
	var ?alpha:Float;
	var ?flipX:Bool;
	var ?distraction:Bool;
	var ?startAnim:String;
	var ?animations:Array<StageAnimData>;
}

typedef StageSoundData =
{
	var name:String;
	var path:String;
	var ?library:String;
}

typedef StageSpecialData =
{
	var type:String;
	var name:String;
	var x:Float;
	var y:Float;
	var ?count:Int;
	var ?spacing:Float;
	var ?scrollFactor:Array<Float>;
	var ?scale:Float;
}

typedef StageCharacterPositions =
{
	var ?bf:Array<Float>;
	var ?gf:Array<Float>;
	var ?dad:Array<Float>;
}

typedef StageData =
{
	var name:String;
	var ?camZoom:Float;
	var ?characterPositions:StageCharacterPositions;
	var ?sprites:Array<StageSpriteData>;
	var ?sounds:Array<StageSoundData>;
	var ?specials:Array<StageSpecialData>;
}

class Stage extends FlxTypedGroup<FlxSprite>
{
	public var stageName:String;
	public var camZoom:Float = 0.9;

	public var onLightningStrike:Void->Void;

	var characterPositions:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	var namedSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	var namedSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	var specialGroups:Map<String, FlxTypedGroup<FlxSprite>> = new Map<String, FlxTypedGroup<FlxSprite>>();
	var data:StageData;

	var isHalloween:Bool = false;
	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;

	var phillyCurLight:Int = 0;
	var trainMoving:Bool = false;
	var trainFrameTiming:Float = 0;
	var trainCars:Int = 8;
	var trainFinishing:Bool = false;
	var trainCooldown:Int = 0;
	var trainStartedMoving:Bool = false;

	var fastCarCanDrive:Bool = true;

	public function new(stage:String)
	{
		super();
		stageName = stage;
		load(stage);
	}

	function load(stage:String):Void
	{
		var path = Paths.getPreloadPath('stages/$stage.json');

		if (!openfl.utils.Assets.exists(path) && !sys.FileSystem.exists(path))
		{
			FlxG.log.error('Stage data missing for "$stage"');
			return;
		}

		try
		{
			var raw:String = openfl.utils.Assets.getText(path);
			data = cast Json.parse(raw);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Failed to parse stage json for "$stage": $e');
			return;
		}

		if (data.camZoom != null)
			camZoom = data.camZoom;

		if (data.characterPositions != null)
		{
			if (data.characterPositions.bf != null)
				characterPositions.set('bf', data.characterPositions.bf);
			if (data.characterPositions.gf != null)
				characterPositions.set('gf', data.characterPositions.gf);
			if (data.characterPositions.dad != null)
				characterPositions.set('dad', data.characterPositions.dad);
		}

		if (data.sounds != null)
		{
			for (sd in data.sounds)
			{
				var snd = new FlxSound().loadEmbedded(Paths.sound(sd.path, sd.library));
				FlxG.sound.list.add(snd);
				namedSounds.set(sd.name, snd);
			}
		}

		if (data.sprites != null)
		{
			for (spriteData in data.sprites)
			{
				if (spriteData.distraction == true && !FlxG.save.data.distractions)
					continue;

				var spr = buildSprite(spriteData);
				namedSprites.set(spriteData.name, spr);
				add(spr);
			}
		}

		if (data.specials != null)
		{
			for (sp in data.specials)
				buildSpecial(sp);
		}

		isHalloween = stageName == 'halloween';
	}

	function buildSprite(sd:StageSpriteData):FlxSprite
	{
		var spr = new FlxSprite(sd.x, sd.y);

		if (sd.animations != null && sd.animations.length > 0)
		{
			if (sd.atlasType == "packer")
				spr.frames = Paths.getPackerAtlas(sd.image, sd.library);
			else
				spr.frames = Paths.getSparrowAtlas(sd.image, sd.library);

			for (a in sd.animations)
			{
				if (a.indices != null && a.indices.length > 0)
					spr.animation.addByIndices(a.name, a.anim, a.indices, "", a.fps, a.loop == true);
				else
					spr.animation.addByPrefix(a.name, a.anim, a.fps, a.loop == true);
			}

			if (sd.startAnim != null)
				spr.animation.play(sd.startAnim);
		}
		else if (sd.image != null)
		{
			spr.loadGraphic(Paths.image(sd.image, sd.library));
		}

		if (sd.scrollFactor != null && sd.scrollFactor.length >= 2)
			spr.scrollFactor.set(sd.scrollFactor[0], sd.scrollFactor[1]);

		if (sd.scale != null)
		{
			spr.setGraphicSize(Std.int(spr.width * sd.scale));
			spr.updateHitbox();
		}

		if (sd.antialiasing != null)
			spr.antialiasing = sd.antialiasing;

		if (sd.visible != null)
			spr.visible = sd.visible;

		if (sd.alpha != null)
			spr.alpha = sd.alpha;

		if (sd.flipX == true)
			spr.flipX = true;

		return spr;
	}

	function buildSpecial(sp:StageSpecialData):Void
	{
		if (sp.type == "limoDancers" && FlxG.save.data.distractions)
		{
			var group = new FlxTypedGroup<FlxSprite>();
			var count = sp.count != null ? sp.count : 5;
			var spacing = sp.spacing != null ? sp.spacing : 370;

			for (i in 0...count)
			{
				var dancer = new BackgroundDancer((spacing * i) + sp.x, sp.y);
				if (sp.scrollFactor != null && sp.scrollFactor.length >= 2)
					dancer.scrollFactor.set(sp.scrollFactor[0], sp.scrollFactor[1]);
				group.add(dancer);
			}

			add(group);
			specialGroups.set(sp.name, group);
		}
		else if (sp.type == "backgroundGirls" && FlxG.save.data.distractions)
		{
			var girls = new BackgroundGirls(sp.x, sp.y);
			girls.scrollFactor.set(0.9, 0.9);

			if (sp.scale != null)
			{
				girls.setGraphicSize(Std.int(girls.width * sp.scale));
				girls.updateHitbox();
			}

			add(girls);
			namedSprites.set(sp.name, girls);
		}
	}

	public function getSprite(name:String):FlxSprite
	{
		return namedSprites.get(name);
	}

	public function hasSprite(name:String):Bool
	{
		return namedSprites.exists(name);
	}

	public function getSound(name:String):FlxSound
	{
		return namedSounds.get(name);
	}

	public function getCharacterPosition(role:String):FlxPoint
	{
		var pos = characterPositions.get(role);
		if (pos == null || pos.length < 2)
			return null;
		return FlxPoint.get(pos[0], pos[1]);
	}

	public function event(name:String):Void
	{
		if (name == 'girlsScared' && hasSprite('bgGirls'))
		{
			cast(getSprite('bgGirls'), BackgroundGirls).getScared();
		}
	}

	public function addTrail(target:FlxSprite):FlxTrail
	{
		var trail = new FlxTrail(target, null, 4, 24, 0.3, 0.069);
		add(cast trail);
		return trail;
	}

	public function stageBeatHit(curBeat:Int):Void
	{
		switch (stageName)
		{
			case 'mall':
				if (FlxG.save.data.distractions)
				{
					if (hasSprite('upperBoppers'))
						getSprite('upperBoppers').animation.play('bop', true);
					if (hasSprite('bottomBoppers'))
						getSprite('bottomBoppers').animation.play('bop', true);
					if (hasSprite('santa'))
						getSprite('santa').animation.play('idle', true);
				}

			case 'limo':
				if (FlxG.save.data.distractions)
				{
					if (specialGroups.exists('limoDancers'))
					{
						specialGroups.get('limoDancers').forEach(function(spr:FlxSprite)
						{
							cast(spr, BackgroundDancer).dance();
						});
					}

					if (FlxG.random.bool(10) && fastCarCanDrive)
						fastCarDrive();
				}

			case 'school':
				if (FlxG.save.data.distractions && hasSprite('bgGirls'))
				{
					cast(getSprite('bgGirls'), BackgroundGirls).dance();
				}

			case 'philly':
				if (FlxG.save.data.distractions)
				{
					if (!trainMoving)
						trainCooldown += 1;

					if (curBeat % 4 == 0)
					{
						for (i in 0...5)
						{
							if (hasSprite('phillyLight$i'))
								getSprite('phillyLight$i').visible = false;
						}

						phillyCurLight = FlxG.random.int(0, 4);

						if (hasSprite('phillyLight$phillyCurLight'))
							getSprite('phillyLight$phillyCurLight').visible = true;
					}

					if (curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8)
					{
						trainCooldown = FlxG.random.int(-4, 0);
						trainStart();
					}
				}
		}

		if (isHalloween && FlxG.save.data.distractions && FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
		{
			lightningStrike(curBeat);
		}
	}

	public function stageUpdate(elapsed:Float):Void
	{
		if (stageName == 'philly' && trainMoving && FlxG.save.data.distractions)
		{
			trainFrameTiming += elapsed;

			if (trainFrameTiming >= 1 / 24)
			{
				updateTrainPos();
				trainFrameTiming = 0;
			}
		}
	}

	function lightningStrike(curBeat:Int):Void
	{
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));

		if (hasSprite('halloweenBG'))
			getSprite('halloweenBG').animation.play('lightning');

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if (onLightningStrike != null)
			onLightningStrike();
	}

	function fastCarDrive():Void
	{
		if (!hasSprite('fastCar'))
			return;

		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		var car = getSprite('fastCar');
		car.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;

		new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
		});
	}

	function resetFastCar():Void
	{
		if (!hasSprite('fastCar'))
			return;

		var car = getSprite('fastCar');
		car.x = -12600;
		car.y = FlxG.random.int(140, 250);
		car.velocity.x = 0;
		fastCarCanDrive = true;
	}

	public function trainStart():Void
	{
		trainMoving = true;

		if (getSound('trainPass') != null && !getSound('trainPass').playing)
			getSound('trainPass').play(true);
	}

	function updateTrainPos():Void
	{
		var trainSound = getSound('trainPass');
		var train = getSprite('phillyTrain');
		var gf = getSprite('bgGirls');

		if (trainSound == null || train == null)
			return;

		if (trainSound.time >= 4700)
		{
			trainStartedMoving = true;
		}

		if (trainStartedMoving)
		{
			train.x -= 400;

			if (train.x < -2000 && !trainFinishing)
			{
				train.x = -1150;
				trainCars -= 1;

				if (trainCars <= 0)
					trainFinishing = true;
			}

			if (train.x < -4000 && trainFinishing)
				trainReset();
		}
	}

	function trainReset():Void
	{
		var train = getSprite('phillyTrain');

		if (train != null)
			train.x = FlxG.width + 200;

		trainMoving = false;
		trainCars = 8;
		trainFinishing = false;
		trainStartedMoving = false;
	}

	override public function destroy():Void
	{
		onLightningStrike = null;
		super.destroy();
	}
}
