package armory.renderpath;

import iron.RenderPath;

class Inc {

	static var path:RenderPath;

	// #if (rp_gi == "Voxel GI")
	// static var voxel_sh:kha.compute.Shader = null;
	// static var voxel_ta:kha.compute.TextureUnit;
	// static var voxel_tb:kha.compute.TextureUnit;
	// static var voxel_tc:kha.compute.TextureUnit;
	// static var voxel_td:kha.compute.TextureUnit;
	// static var voxel_te:kha.compute.TextureUnit;
	// static var voxel_tf:kha.compute.TextureUnit;
	// static var voxel_ca:kha.compute.ConstantLocation;
	// static var voxel_cb:kha.compute.ConstantLocation;
	// static var voxel_cc:kha.compute.ConstantLocation;
	// static var voxel_cd:kha.compute.ConstantLocation;
	// static var voxel_ce:kha.compute.ConstantLocation;
	// static var voxel_cf:kha.compute.ConstantLocation;
	// static var voxel_cg:kha.compute.ConstantLocation;
	// static var voxel_ch:kha.compute.ConstantLocation;
	// static var voxel_ci:kha.compute.ConstantLocation;
	// static var m = iron.math.Mat4.identity();
	// #end
	// #if (rp_gi_bounces)
	// static var bounce_sh:kha.compute.Shader = null;
	// static var bounce_ta:kha.compute.TextureUnit;
	// static var bounce_tb:kha.compute.TextureUnit;
	// static var bounce_tc:kha.compute.TextureUnit;
	// #end
	public static var superSample = 1.0;

	static var pointIndex = 0;
	static var spotIndex = 0;
	static var lastFrame = -1;

	#if ((rp_gi != "Off") && arm_config)
	static var voxelsCreated = false;
	#end

	public static function init(_path:RenderPath) {
		path = _path;

		#if arm_config
		var config = armory.data.Config.raw;
		for (l in iron.Scene.active.lights) {
			l.data.raw.shadowmap_size = l.data.raw.type == "sun" ?
				config.rp_shadowmap_cascade :
				config.rp_shadowmap_cube;
		}
		superSample = config.rp_supersample;
		#else
		
		#if (rp_supersampling == 1.5)
		superSample = 1.5;
		#elseif (rp_supersampling == 2)
		superSample = 2.0;
		#elseif (rp_supersampling == 4)
		superSample = 4.0;
		#end
		
		#end
	}

	public static function bindShadowMap() {
		for (l in iron.Scene.active.lights) {
			if (!l.visible || !l.data.raw.cast_shadow || l.data.raw.type != "sun") continue;
			var n = "shadowMap";
			path.bindTarget(n, n);
			break;
		}
		for (i in 0...pointIndex) {
			var n = "shadowMapPoint[" + i + "]";
			path.bindTarget(n, n);
		}
		for (i in 0...spotIndex) {
			var n = "shadowMapSpot[" + i + "]";
			path.bindTarget(n, n);
		}
	}

	static function shadowMapName(l:iron.object.LightObject):String {
		if (l.data.raw.type == "sun") return "shadowMap";
		if (l.data.raw.type == "point") return "shadowMapPoint[" + pointIndex + "]";
		else return "shadowMapSpot[" + spotIndex + "]"; 
	}

	static function getShadowMap(l:iron.object.LightObject):String {
		var target = shadowMapName(l);
		var rt = path.renderTargets.get(target);
		// Create shadowmap on the fly
		if (rt == null) {
			if (path.light.data.raw.shadowmap_cube) {
				// Cubemap size
				var size = path.light.data.raw.shadowmap_size;
				var t = new RenderTargetRaw();
				t.name = target;
				t.width = size;
				t.height = size;
				t.format = "DEPTH16";
				t.is_cubemap = true;
				rt = path.createRenderTarget(t);
			}
			else { // Non-cube sm
				var sizew = path.light.data.raw.shadowmap_size;
				var sizeh = sizew;
				#if arm_csm // Cascades - atlas on x axis
				if (l.data.raw.type == "sun") {
					sizew = sizew * iron.object.LightObject.cascadeCount;
				}
				#end
				var t = new RenderTargetRaw();
				t.name = target;
				t.width = sizew;
				t.height = sizeh;
				t.format = "DEPTH16";
				rt = path.createRenderTarget(t);
			}
		}
		return target;
	}

	public static function drawShadowMap() {
		#if (rp_shadowmap)

		#if rp_probes
		// Share shadow map with probe
		if (lastFrame == RenderPath.active.frame) return;
		lastFrame = RenderPath.active.frame;
		#end

		pointIndex = 0;
		spotIndex = 0;
		for (l in iron.Scene.active.lights) {
			if (!l.visible || !l.data.raw.cast_shadow) continue;
			path.light = l;
			var shadowmap = Inc.getShadowMap(l);
			var faces = l.data.raw.shadowmap_cube ? 6 : 1;
			for (i in 0...faces) {
				if (faces > 1) path.currentFace = i;
				path.setTarget(shadowmap);
				path.clearTarget(null, 1.0);
				path.drawMeshes("shadowmap");
			}
			path.currentFace = -1;

			if (l.data.raw.type == "point") pointIndex++;
			else if (l.data.raw.type == "spot" || l.data.raw.type == "area") spotIndex++;
		}

		// One light at a time for now, precompute all lights for tiled
		// #if rp_soft_shadows

		// if (l.raw.type != "point") {
		// 	path.setTarget("visa"); // Merge using min blend
		// 	Inc.bindShadowMap();
		// 	path.drawShader("shader_datas/dilate_pass/dilate_pass_x");

		// 	path.setTarget("visb");
		// 	path.bindTarget("visa", "shadowMap");
		// 	path.drawShader("shader_datas/dilate_pass/dilate_pass_y");
		// }

		// path.setTarget("visa", ["dist"]);
		// //if (i == 0) path.clearTarget(0x00000000);
		// if (l.raw.type != "point") path.bindTarget("visb", "dilate");
		// Inc.bindShadowMap();
		// //path.bindTarget("_main", "gbufferD");
		// path.bindTarget("gbuffer0", "gbuffer0");
		// path.drawShader("shader_datas/visibility_pass/visibility_pass");
		
		// path.setTarget("visb");
		// path.bindTarget("visa", "tex");
		// path.bindTarget("gbuffer0", "gbuffer0");
		// path.bindTarget("dist", "dist");
		// path.drawShader("shader_datas/blur_shadow_pass/blur_shadow_pass_x");

		// path.setTarget("visa");
		// path.bindTarget("visb", "tex");
		// path.bindTarget("gbuffer0", "gbuffer0");
		// path.bindTarget("dist", "dist");
		// path.drawShader("shader_datas/blur_shadow_pass/blur_shadow_pass_y");
		// #end

		#end // rp_shadowmap
	}
	
	public static function applyConfig() {
		#if arm_config
		var config = armory.data.Config.raw;
		// Resize shadow map
		var l = path.light;
		if (l.data.raw.type == "sun" && l.data.raw.shadowmap_size != config.rp_shadowmap_cascade) {
			l.data.raw.shadowmap_size = config.rp_shadowmap_cascade;
			var rt = path.renderTargets.get("shadowMap");
			if (rt != null) {
				rt.unload();
				path.renderTargets.remove("shadowMap");
			}
		}
		else if (l.data.raw.shadowmap_size != config.rp_shadowmap_cube) {
			l.data.raw.shadowmap_size = config.rp_shadowmap_cube;
			var rt = path.renderTargets.get("shadowMapCube");
			if (rt != null) {
				rt.unload();
				path.renderTargets.remove("shadowMapCube");
			}
		}
		if (superSample != config.rp_supersample) {
			superSample = config.rp_supersample;
			for (rt in path.renderTargets) {
				if (rt.raw.width == 0 && rt.raw.scale != null) {
					rt.raw.scale = getSuperSampling();
				}
			}
			path.resize();
		}
		// Init voxels
		#if (rp_gi != "Off")
		if (!voxelsCreated) initGI();
		#end
		#end // arm_config
	}

	// #if (rp_shadowmap && kha_webgl)
	// public static function initEmpty() {
	// 	// Bind empty when requested target is not found
	// 	var tempty = new RenderTargetRaw();
	// 	tempty.name = "arm_empty";
	// 	tempty.width = 1;
	// 	tempty.height = 1;
	// 	tempty.format = "DEPTH16";
	// 	path.createRenderTarget(tempty);
	// 	var temptyCube = new RenderTargetRaw();
	// 	temptyCube.name = "arm_empty_cube";
	// 	temptyCube.width = 1;
	// 	temptyCube.height = 1;
	// 	temptyCube.format = "DEPTH16";
	// 	temptyCube.is_cubemap = true;
	// 	path.createRenderTarget(temptyCube);
	// }
	// #end

	#if (rp_translucency)
	public static function initTranslucency() {
		path.createDepthBuffer("main", "DEPTH24");

		var t = new RenderTargetRaw();
		t.name = "accum";
		t.width = 0;
		t.height = 0;
		t.displayp = getDisplayp();
		t.format = "RGBA64";
		t.scale = getSuperSampling();
		t.depth_buffer = "main";
		path.createRenderTarget(t);

		var t = new RenderTargetRaw();
		t.name = "revealage";
		t.width = 0;
		t.height = 0;
		t.displayp = getDisplayp();
		t.format = "R16";
		t.scale = getSuperSampling();
		t.depth_buffer = "main";
		path.createRenderTarget(t);

		path.loadShader("shader_datas/translucent_resolve/translucent_resolve");
	}

	public static function drawTranslucency(target:String) {
		path.setTarget("accum");
		path.clearTarget(0xff000000);
		path.setTarget("revealage");
		path.clearTarget(0xffffffff);
		path.setTarget("accum", ["revealage"]);
		#if rp_shadowmap
		{
			bindShadowMap();
		}
		#end
		path.drawMeshes("translucent");
		#if rp_render_to_texture
		{
			path.setTarget(target);
		}
		#else
		{
			path.setTarget("");
		}
		#end
		path.bindTarget("accum", "gbuffer0");
		path.bindTarget("revealage", "gbuffer1");
		path.drawShader("shader_datas/translucent_resolve/translucent_resolve");
	}
	#end

	#if (rp_gi != "Off")
	public static function initGI(tname = "voxels") {
		#if arm_config
		var config = armory.data.Config.raw;
		if (config.rp_gi != true || voxelsCreated) return;
		voxelsCreated = true;
		#end

		var t = new RenderTargetRaw();
		t.name = tname;
		#if (rp_gi == "Voxel AO")
		{
			t.format = "R8";
		}
		#else
		{
			t.format = "RGBA32";
		}
		#end
		var res = getVoxelRes();
		var resZ =  getVoxelResZ();
		t.width = res;
		t.height = res;
		t.depth = Std.int(res * resZ);
		t.is_image = true;
		t.mipmaps = true;
		path.createRenderTarget(t);

		#if arm_voxelgi_temporal
		{
			var tB = new RenderTargetRaw();
			tB.name = t.name + "B";
			tB.format = t.format;
			tB.width = t.width;
			tB.height = t.height;
			tB.depth = t.depth;
			tB.is_image = t.is_image;
			tB.mipmaps = t.mipmaps;
			path.createRenderTarget(tB);
		}
		#end
	}
	#end

	public static inline function getCubeSize():Int {
		#if (rp_shadowmap_cube == 256)
		return 256;
		#elseif (rp_shadowmap_cube == 512)
		return 512;
		#elseif (rp_shadowmap_cube == 1024)
		return 1024;
		#elseif (rp_shadowmap_cube == 2048)
		return 2048;
		#elseif (rp_shadowmap_cube == 4096)
		return 4096;
		#else
		return 0;
		#end
	}

	public static inline function getCascadeSize():Int {
		#if (rp_shadowmap_cascade == 256)
		return 256;
		#elseif (rp_shadowmap_cascade == 512)
		return 512;
		#elseif (rp_shadowmap_cascade == 1024)
		return 1024;
		#elseif (rp_shadowmap_cascade == 2048)
		return 2048;
		#elseif (rp_shadowmap_cascade == 4096)
		return 4096;
		#elseif (rp_shadowmap_cascade == 8192)
		return 8192;
		#elseif (rp_shadowmap_cascade == 16384)
		return 16384;
		#else
		return 0;
		#end
	}

	public static inline function getVoxelRes():Int {
		#if (rp_voxelgi_resolution == 512)
		return 512;
		#elseif (rp_voxelgi_resolution == 256)
		return 256;
		#elseif (rp_voxelgi_resolution == 128)
		return 128;
		#elseif (rp_voxelgi_resolution == 64)
		return 64;
		#elseif (rp_voxelgi_resolution == 32)
		return 32;
		#else
		return 0;
		#end
	}

	public static inline function getVoxelResZ():Float {
		#if (rp_voxelgi_resolution_z == 1.0)
		return 1.0;
		#elseif (rp_voxelgi_resolution_z == 0.5)
		return 0.5;
		#elseif (rp_voxelgi_resolution_z == 0.25)
		return 0.25;
		#else
		return 0.0;
		#end
	}

	public static inline function getSuperSampling():Float {
		return superSample;
	}

	public static inline function getHdrFormat():String {
		#if rp_hdr
		return "RGBA64";
		#else
		return "RGBA32";
		#end
	}

	public static inline function getDisplayp():Null<Int> {
		#if rp_resolution_filter // Custom resolution set
		return Main.resolutionSize;
		#else
		return null;
		#end
	}

	// #if (rp_gi == "Voxel GI")
	// public static function computeVoxelsBegin() {
	// 	if (voxel_sh == null) {
	// 		voxel_sh = path.getComputeShader("voxel_light");
	// 		voxel_ta = voxel_sh.getTextureUnit("voxelsOpac");
	// 		// voxel_tb = voxel_sh.getTextureUnit("voxelsNor");
	// 		voxel_tc = voxel_sh.getTextureUnit("voxels");
	// 		voxel_td = voxel_sh.getTextureUnit("shadowMap");
	// 		voxel_te = voxel_sh.getTextureUnit("shadowMapSpot");
	// 		voxel_tf = voxel_sh.getTextureUnit("shadowMapPoint");
			
	// 		voxel_ca = voxel_sh.getConstantLocation("lightPos");
	// 		voxel_cb = voxel_sh.getConstantLocation("lightColor");
	// 		voxel_cc = voxel_sh.getConstantLocation("lightType");
	// 		voxel_cd = voxel_sh.getConstantLocation("lightDir");
	// 		voxel_ci = voxel_sh.getConstantLocation("spotData");
	// 		#if (rp_shadowmap)
	// 		voxel_ce = voxel_sh.getConstantLocation("lightShadow");
	// 		voxel_cf = voxel_sh.getConstantLocation("lightProj");
	// 		voxel_cg = voxel_sh.getConstantLocation("LVP");
	// 		voxel_ch = voxel_sh.getConstantLocation("shadowsBias");
	// 		#end
	// 	}
	// 	path.clearImage("voxels", 0x00000000);
	// }
	// public static function computeVoxels() {
	// 	var rts = path.renderTargets;
	// 	var res = Inc.getVoxelRes();
	// 	var lights = iron.Scene.active.lights;
	// 	for (i in 0...lights.length) {
	// 		var l = lights[i];
	// 		if (!l.visible) continue;
	// 		path.light = l;

	// 		kha.compute.Compute.setShader(voxel_sh);
	// 		kha.compute.Compute.setTexture(voxel_ta, rts.get("voxelsOpac").image, kha.compute.Access.Read);
	// 		// kha.compute.Compute.setTexture(voxel_tb, rts.get("voxelsNor").image, kha.compute.Access.Read);
	// 		kha.compute.Compute.setTexture(voxel_tc, rts.get("voxels").image, kha.compute.Access.Write);

	// 		#if (rp_shadowmap)
	// 		if (l.data.raw.type == "sun") {
	// 			kha.compute.Compute.setSampledTexture(voxel_td, rts.get("shadowMap").image);
	// 			kha.compute.Compute.setInt(voxel_ce, 1); // lightShadow
	// 		}
	// 		else if (l.data.raw.type == "spot") {
	// 			kha.compute.Compute.setSampledTexture(voxel_te, rts.get("shadowMapSpot[0]").image);
	// 			kha.compute.Compute.setInt(voxel_ce, 2);
	// 		}
	// 		else {
	// 			kha.compute.Compute.setSampledCubeMap(voxel_tf, rts.get("shadowMapPoint[0]").cubeMap);
	// 			kha.compute.Compute.setInt(voxel_ce, 3);
	// 		}
			
	// 		// lightProj
	// 		var near = l.data.raw.near_plane;
	// 		var far = l.data.raw.far_plane;
	// 		var a:kha.FastFloat = far + near;
	// 		var b:kha.FastFloat = far - near;
	// 		var f2:kha.FastFloat = 2.0;
	// 		var c:kha.FastFloat = f2 * far * near;
	// 		var vx:kha.FastFloat = a / b;
	// 		var vy:kha.FastFloat = c / b;
	// 		kha.compute.Compute.setFloat2(voxel_cf, vx, vy);
	// 		// LVP
	// 		m.setFrom(l.VP);
	// 		m.multmat(iron.object.Uniforms.biasMat);
	// 		kha.compute.Compute.setMatrix(voxel_cg, m.self);
	// 		// shadowsBias
	// 		kha.compute.Compute.setFloat(voxel_ch, l.data.raw.shadows_bias);
	// 		#end

	// 		// lightPos
	// 		kha.compute.Compute.setFloat3(voxel_ca, l.transform.worldx(), l.transform.worldy(), l.transform.worldz());
	// 		// lightCol
	// 		var f = l.data.raw.strength;
	// 		kha.compute.Compute.setFloat3(voxel_cb, l.data.raw.color[0] * f, l.data.raw.color[1] * f, l.data.raw.color[2] * f);
	// 		// lightType
	// 		kha.compute.Compute.setInt(voxel_cc, iron.data.LightData.typeToInt(l.data.raw.type));
	// 		// lightDir
	// 		var v = l.look();
	// 		kha.compute.Compute.setFloat3(voxel_cd, v.x, v.y, v.z);
	// 		// spotData
	// 		if (l.data.raw.type == "spot") {
	// 			var vx = l.data.raw.spot_size;
	// 			var vy = vx - l.data.raw.spot_blend;
	// 			kha.compute.Compute.setFloat2(voxel_ci, vx, vy);
	// 		}

	// 		kha.compute.Compute.compute(res, res, res);
	// 	}
	// }
	// public static function computeVoxelsEnd() {
	// 	var rts = path.renderTargets;
	// 	var res = Inc.getVoxelRes();
	// 	path.generateMipmaps("voxels");

	// 	// #if (rp_gi_bounces)
	// 	// if (bounce_sh == null) {
	// 	// 	bounce_sh = path.getComputeShader("voxel_bounce");
	// 	// 	bounce_ta = bounce_sh.getTextureUnit("voxelsNor");
	// 	// 	bounce_tb = bounce_sh.getTextureUnit("voxelsFrom");
	// 	// 	bounce_tc = bounce_sh.getTextureUnit("voxelsTo");
	// 	// }
	// 	// // path.clearImage("voxelsBounce", 0x00000000);
	// 	// kha.compute.Compute.setShader(bounce_sh);
	// 	// kha.compute.Compute.setTexture(bounce_ta, rts.get("voxelsNor").image, kha.compute.Access.Read);
	// 	// kha.compute.Compute.setTexture3DParameters(bounce_tb, kha.graphics4.TextureAddressing.Clamp, kha.graphics4.TextureAddressing.Clamp, kha.graphics4.TextureAddressing.Clamp, kha.graphics4.TextureFilter.LinearFilter, kha.graphics4.TextureFilter.PointFilter, kha.graphics4.MipMapFilter.LinearMipFilter);
	// 	// kha.compute.Compute.setSampledTexture(bounce_tb, rts.get("voxels").image);
	// 	// kha.compute.Compute.setTexture(bounce_tc, rts.get("voxelsBounce").image, kha.compute.Access.Write);
	// 	// kha.compute.Compute.compute(res, res, res);
	// 	// path.generateMipmaps("voxelsBounce");
	// 	// #end
	// }
	// #end
}
