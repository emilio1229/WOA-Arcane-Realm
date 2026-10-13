class_name GloamwickMaterials
extends RefCounted

## Central material library for Gloamwick.
##
## The imported OBJ kit ships with broken material paths (they point at the
## original author's absolute Windows folders), so every textured mesh would
## import as a blank white surface. This library rebuilds each material from the
## textures that actually live in the project, keyed by the material name baked
## into the imported mesh surfaces.
##
## Usage:
##   var mesh := load("res://OBJ/CommonTree_1.obj") as Mesh
##   GloamwickMaterials.apply_to_mesh(mesh)

# material name -> [texture path, flags]
# flags: "alpha" = cutout vegetation, "emissive" = glowing surface,
#        "metal" = metallic look, "glass" = transparent glass.
const MATERIALS := {
	# --- Nature ---
	"Bark_DeadTree": ["res://Textures/Bark_DeadTree.png", ""],
	"Bark_NormalTree": ["res://Textures/Bark_NormalTree.png", ""],
	"Bark_TwistedTree": ["res://Textures/Bark_TwistedTree.png", ""],
	"Leaves": ["res://Textures/Leaves.png", "alpha"],
	"Leaves_NormalTree": ["res://Textures/Leaves_NormalTree_C.png", "alpha"],
	"Leaves_Pine": ["res://Textures/Leaf_Pine_C.png", "alpha"],
	"Leaves_TwistedTree": ["res://Textures/Leaves_TwistedTree_C.png", "alpha"],
	"Flowers": ["res://Textures/Flowers.png", "alpha"],
	"Grass": ["res://Textures/Grass.png", "alpha"],
	"Mushrooms": ["res://Textures/Mushrooms.png", ""],
	"PathRocks": ["res://Textures/PathRocks_Diffuse.png", ""],
	"Rocks": ["res://Textures/Rocks_Diffuse.png", ""],
	# --- Architecture ---
	"MI_Brick": ["res://Textures/T_Brick_BaseColor.png", ""],
	"MI_RedBrick": ["res://Textures/T_RedBrick_BaseColor.png", ""],
	"MI_UnevenBrick": ["res://Textures/T_UnevenBrick_BaseColor.png", ""],
	"MI_RoundTiles": ["res://Textures/T_RoundTiles_BaseColor.png", ""],
	"MI_Plaster": ["res://Textures/T_Plaster_BaseColor.png", ""],
	"MI_RockTrim": ["res://Textures/T_RockTrim_BaseColor.png", ""],
	"MI_WoodTrim": ["res://Textures/T_WoodTrim_BaseColor.png", ""],
	"MI_WoodTrim_Wear": ["res://Textures/T_WoodTrim_BaseColor.png", ""],
	"MI_MetalOrnaments": ["", "metal"],
	"MI_Vine": ["res://Textures/T_VineLeaf.png", "alpha"],
	"MI_WindowGlass": ["res://Textures/T_WindowGradient.png", "glass"],
	# --- Props ---
	"MI_Banner": ["res://Textures/T_Trim_Cloth_BaseColor.png", ""],
	"MI_Trim_Cloth": ["res://Textures/T_Trim_Cloth_BaseColor.png", ""],
	"MI_Trim_Furniture": ["res://Textures/T_Trim_Furniture_BaseColor.png", ""],
	"MI_Trim_Metal": ["res://Textures/T_Trim_Metal_BaseColor.png", "metal"],
	"MI_Trim_Metal_Vertex": ["res://Textures/T_Trim_Metal_BaseColor.png", "metal"],
	"MI_Trim_Props": ["res://Textures/T_Trim_Props_BaseColor.png", ""],
	"MI_Trim_Props_Vertex": ["res://Textures/T_Trim_Props_BaseColor.png", ""],
	"MI_Page_Empty": ["res://Textures/T_Page_Noise.png", ""],
	# --- Fallbacks ---
	"Material": ["", ""],
	"wood": ["", ""],
}

# Gentle tints that pull the kit toward Gloamwick's twilight palette.
const TINTS := {
	"MI_RoundTiles": Color(0.55, 0.42, 0.42),
	"MI_WoodTrim": Color(0.80, 0.74, 0.70),
	"MI_Plaster": Color(0.82, 0.80, 0.86),
	# Vegetation pulled toward a muted twilight green so it stops reading white.
	"Leaves": Color(0.5, 0.6, 0.48),
	"Leaves_NormalTree": Color(0.5, 0.6, 0.48),
	"Leaves_Pine": Color(0.42, 0.55, 0.46),
	"Leaves_TwistedTree": Color(0.44, 0.56, 0.46),
	"Flowers": Color(0.75, 0.6, 0.75),
	"Grass": Color(0.55, 0.6, 0.5),
	"Bark_NormalTree": Color(0.7, 0.62, 0.64),
	"Bark_DeadTree": Color(0.66, 0.6, 0.64),
	"Bark_TwistedTree": Color(0.64, 0.58, 0.62),
	"Rocks": Color(0.42, 0.4, 0.5),
	"PathRocks": Color(0.5, 0.48, 0.56),
}

const DEFAULT_COLORS := {
	"wood": Color(0.16, 0.09, 0.06),
	"Material": Color(0.28, 0.24, 0.3),
	"MI_MetalOrnaments": Color(0.32, 0.3, 0.36),
	"MI_WindowGlass": Color(0.95, 0.55, 0.2),
}

static var _cache: Dictionary = {}

## Build (or fetch) the material for one imported surface material name.
static func get_material(material_name: String) -> StandardMaterial3D:
	if _cache.has(material_name):
		return _cache[material_name]
	var data: Array = MATERIALS.get(material_name, ["", ""])
	var mat := StandardMaterial3D.new()
	mat.resource_name = material_name
	var flags: String = data[1]
	if data[0] != "" and ResourceLoader.exists(data[0]):
		mat.albedo_texture = load(data[0])
	elif DEFAULT_COLORS.has(material_name):
		mat.albedo_color = DEFAULT_COLORS[material_name]
	if TINTS.has(material_name):
		mat.albedo_color = mat.albedo_color * TINTS[material_name]
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.85
	if flags.contains("alpha"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 1.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	elif flags.contains("glass"):
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.62, 0.28)
		mat.emission_energy_multiplier = 1.6
		mat.albedo_color = Color(1.0, 0.7, 0.35)
	elif flags.contains("metal"):
		mat.metallic = 0.75
		mat.roughness = 0.45
	elif DEFAULT_COLORS.has(material_name):
		# Flat colour fallback for meshes authored without textures.
		mat.albedo_color = DEFAULT_COLORS[material_name]
	_cache[material_name] = mat
	return mat


## Replace every surface material of an imported OBJ mesh with a project material.
## Idempotent: the mesh is skipped if it was already processed.
static func apply_to_mesh(mesh: Mesh) -> void:
	if mesh == null or mesh.has_meta("gloamwick_materialized"):
		return
	for i in mesh.get_surface_count():
		var original := mesh.surface_get_material(i)
		var mat_name := "Material"
		if original != null and original.resource_name != "":
			mat_name = original.resource_name
		mesh.surface_set_material(i, get_material(mat_name))
	mesh.set_meta("gloamwick_materialized", true)


## A helper that walks an instanced scene/mesh node and applies materials.
static func apply_to_instance(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		apply_to_mesh(node.mesh)
	for child in node.get_children():
		apply_to_instance(child)