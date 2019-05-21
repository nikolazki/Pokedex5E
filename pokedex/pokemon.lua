local utils = require "utils.utils"
local pokedex = require "pokedex.pokedex"
local natures = require "pokedex.natures"
local storage = require "pokedex.storage"
local movedex = require "pokedex.moves"

local M = {}

local feat_to_skill = {
	Brawny="Athletics",
	Perceptive="Perception",
	Acrobat= "Acrobatics",
	["Quick-Fingered"]="Sleight of Hand",
	Stealthy="Stealth"
}
local resilient = {
	["Resilient (STR)"]= "STR",
	["Resilient (CON)"]= "CON",
	["Resilient (DEX)"]= "DEX",
	["Resilient (INT)"]= "INT",
	["Resilient (WIS)"]= "WIS",
	["Resilient (CHA)"]= "CHA",
}
local feat_to_attribute = {
	["Resilient (STR)"]= "STR",
	["Resilient (CON)"]= "CON",
	["Resilient (DEX)"]= "DEX",
	["Resilient (INT)"]= "INT",
	["Resilient (WIS)"]= "WIS",
	["Resilient (CHA)"]= "CHA",
	["Athlete (STR)"]= "STR",
	["Athlete (DEX)"]="DEX",
	["Quick-Fingered"]= "DEX",
	Stealthy="DEX",
	Brawny="STR",
	Perceptive="WIS",
	Acrobat="DEX"
}

local function add_tables(T1, T2)
	local copy = utils.shallow_copy(T1)
	for k,v in pairs(T2) do
		if copy[k] then
			copy[k] = copy[k] + v
		end
	end
	return copy
end

function M.get_senses(pokemon)
	return pokedex.get_senses(M.get_current_species(pokemon))
end

local function get_attributes_from_feats(pokemon)
	local m = {STR=0, DEX=0, CON=0, INT=0, WIS=0, CHA=0}
	for _, feat in pairs(M.get_feats(pokemon)) do
		local attr = feat_to_attribute[feat]
		if attr then
			m[attr] = m[attr] + 1
		end
	end
	return m
end

function M.get_attributes(pokemon)
	local b = pokedex.get_base_attributes(M.get_caught_species(pokemon))
	local a = M.get_increased_attributes(pokemon) or {}
	local n = natures.get_nature_attributes(M.get_nature(pokemon)) or {}
	local f = get_attributes_from_feats(pokemon)
	return add_tables(add_tables(add_tables(b, n), a), f)
end

function M.get_max_attributes(pokemon)
	local m = {STR= 20,DEX= 20,CON= 20,INT= 20,WIS= 20,CHA= 20}
	local n = natures.get_nature_attributes(M.get_nature(pokemon)) or {}
	local t = add_tables(m, n)
	for key, value in pairs(t) do
		t[key] = value > 20 and value or 20 
	end
	return t
end

function M.get_increased_attributes(pokemon)
	return pokemon.attributes.increased
end

function M.get_experience_for_level(pokemon)
	return pokedex.get_experience_for_level(M.get_current_level(pokemon))
end

function M.have_ability(pokemon, ability)
	local count = 0
	for _, f in pairs(M.get_abilities(pokemon)) do
		if f == ability then
			return true
		end
	end
	return false
end

function M.have_feat(pokemon, feat)
	local count = 0
	for _, f in pairs(M.get_feats(pokemon)) do
		if f == feat then
			count = count + 1
		end
	end
	return count > 0, count
end

function M.get_exp(pokemon)
	return pokemon.exp or 0
end

function M.set_exp(pokemon, exp)
	pokemon.exp = exp
	storage.set_pokemon_exp(M.get_id(pokemon), exp)
end

function M.update_increased_attributes(pokemon, increased)
	local function get_hp_from_con(pokemon)
		local level = M.get_current_level(pokemon)

		local con = M.get_attributes(pokemon).CON
		local con_mod = math.floor((con - 10) / 2)
		local from_con_mod = con_mod * level
		return from_con_mod
	end
	
	local b = M.get_increased_attributes(pokemon)

	-- Remove HP from CON
	local current = M.get_max_hp(pokemon)
	M.set_max_hp(pokemon, current - get_hp_from_con(pokemon))

	-- Add attribtues
	local n = add_tables(b, increased)
	pokemon.attributes.increased = n

	-- Add HP from CON
	local current = M.get_max_hp(pokemon)
	M.set_max_hp(pokemon, current + get_hp_from_con(pokemon))
end

function M.save(pokemon)
	return storage.update_pokemon(pokemon)
end

function M.get_speed_of_type(pokemon)
	local species = M.get_current_species(pokemon)
	local type = pokedex.get_pokemon_type(species)[1]
	local mobile_feet = 0
	if M.have_feat(pokemon, "Mobile") then
		mobile_feet = 10
	end
	if type == "Flying" then
		local speed = pokedex.get_flying_speed(species) 
		return speed ~= 0 and speed+mobile_feet or speed, "Flying"
	elseif type == "Water" then
		local speed = pokedex.get_swimming_speed(species) 
		return speed ~= 0 and speed+mobile_feet or speed, "Swimming"
	else
		local speed = pokedex.get_walking_speed(species) 
		return speed ~= 0 and speed+mobile_feet or speed, "Walking"
	end
end

function M.get_all_speed(pokemon)
	local species = M.get_current_species(pokemon)
	local mobile_feet = 0
	if M.have_feat(pokemon, "Mobile") then
		mobile_feet = 10
	end
	local w = pokedex.get_walking_speed(species) 
	local s = pokedex.get_swimming_speed(species) 
	local c = pokedex.get_climbing_speed(species) 
	local f = pokedex.get_flying_speed(species) 
	return {Walking= w ~= 0 and w+mobile_feet or w, Swimming=s ~= 0 and s+mobile_feet or s, 
	Flying= f ~= 0 and f+mobile_feet or f, Climbing=c ~= 0 and c+mobile_feet or c}
end

function M.set_current_hp(pokemon, hp)
	pokemon.hp.current = hp
	storage.set_pokemon_current_hp(M.get_id(pokemon), hp)
end

function M.get_current_hp(pokemon)
	return pokemon.hp.current
end

function M.set_max_hp(pokemon, hp, force)
	if force then
		pokemon.hp.edited = force
	end
	
	pokemon.hp.max = hp
	storage.set_pokemon_max_hp(M.get_id(pokemon), hp)
end

function M.get_max_hp_edited(pokemon)
	return pokemon.hp.edited
end

function M.get_max_hp(pokemon)
	if M.have_ability(pokemon, "Paper Thin") then
		return 1
	end
	
	local tough_feat = 0
	if M.have_feat(pokemon, "Tough") then
		tough_feat = M.get_current_level(pokemon) * 2
	end

	return pokemon.hp.max + tough_feat
end

function M.get_current_species(pokemon)
	return pokemon.species.current
end

local function set_species(pokemon, species)
	pokemon.species.current = species
end

function M.get_caught_species(pokemon)
	return pokemon.species.caught
end

function M.get_current_level(pokemon)
	return pokemon.level.current
end

function M.get_caught_level(pokemon)
	return pokemon.level.caught
end

function M.set_move(pokemon, new_move, index)
	local pp = movedex.get_move_pp(new_move)
	for name, move in pairs(M.get_moves(pokemon)) do
		if move.index == index then
			pokemon.moves[name] = nil
			pokemon.moves[new_move] = {pp=pp, index=index}
			return
		end
	end
	pokemon.moves[new_move] = {pp=pp, index=index}
end

function M.get_moves(pokemon)
	return pokemon.moves
end

function M.get_nature(pokemon)
	return pokemon.nature
end

function M.get_id(pokemon)
	return pokemon.id
end

function M.get_type(pokemon)
	return pokedex.get_pokemon_type(M.get_current_species(pokemon))
end

function M.get_STAB_bonus(pokemon)
	return pokedex.level_data(M.get_current_level(pokemon)).STAB
end

function M.get_proficency_bonus(pokemon)
	return pokedex.level_data(M.get_current_level(pokemon)).prof
end

function M.update_abilities(pokemon, abilities)
	pokemon.abilities = abilities
end

function M.update_feats(pokemon, feats)
	pokemon.feats = feats
end

function M.get_feats(pokemon)
	return pokemon.feats or {}
end

function M.get_abilities(pokemon, as_raw)
	local species = M.get_current_species(pokemon)
	local t = {}
	t = pokemon.abilities or pokedex.get_pokemon_abilities(species) or {}
	if not as_raw and M.have_feat(pokemon, "Hidden Ability") then
		local hidden = pokedex.get_pokemon_hidden_ability(species)
		local added = false
		for _, h in pairs(t) do
			if h == hidden then
				added = true
			end
		end
		if not added then
			table.insert(t, hidden)
		end
	end
	return t
end

function M.get_skills(pokemon)
	local skills = pokedex.get_pokemon_skills(M.get_current_species(pokemon)) or {}
	for feat, skill in pairs(feat_to_skill) do
		local added = false
		if M.have_feat(pokemon, feat) then
			for i=#skills, -1, -1 do
				if skill == skills[i] then
					table.remove(skills, i)
					table.insert(skills, skill .. " (e)")
					added = true
				end
			end
			if not added then
				table.insert(skills, skill)
			end
		end
	end

	return skills
end

function M.get_move_pp(pokemon, move)
	return pokemon.moves[move].pp
end

function M.get_move_pp_max(pokemon, move)
	local _, pp_extra = M.have_feat(pokemon, "Tireless")
	local move_pp = movedex.get_move_pp(move)
	if type(move_pp) == "string" then
		return 99
	end
	return movedex.get_move_pp(move) + pp_extra
end

function M.get_move_index(pokemon, move)
	return pokemon.moves[move].index
end

function M.reset(pokemon)
	M.set_current_hp(pokemon, M.get_max_hp(pokemon))
	for name, move in pairs(M.get_moves(pokemon)) do
		M.reset_move_pp(pokemon, name)
	end
end

function M.get_vulnerabilities(pokemon)
	return pokedex.get_pokemon_vulnerabilities(M.get_current_species(pokemon))
end

function M.get_immunities(pokemon)
	return pokedex.get_pokemon_immunities(M.get_current_species(pokemon))
end

function M.get_resistances(pokemon)
	return pokedex.get_pokemon_resistances(M.get_current_species(pokemon))
end

function M.decrease_move_pp(pokemon, move)
	local move_pp = M.get_move_pp(pokemon, move)
	if type(move_pp) == "string" then
		return
	end
	local pp = math.max(move_pp - 1, 0)
	storage.set_pokemon_move_pp(M.get_id(pokemon), move, pp)
	pokemon.moves[move].pp = pp
end

function M.increase_move_pp(pokemon, move)
	local move_pp = M.get_move_pp(pokemon, move)
	if type(move_pp) == "string" then
		return
	end
	local max_pp = M.get_move_pp_max(pokemon, move)
	local pp = math.min(move_pp + 1, max_pp)
	storage.set_pokemon_move_pp(M.get_id(pokemon), move, pp)
	pokemon.moves[move].pp = pp
end


function M.reset_move_pp(pokemon, move)
	local pp = M.get_move_pp_max(pokemon, move)
	storage.set_pokemon_move_pp(M.get_id(pokemon), move, pp)
	pokemon.moves[move].pp = pp
end

local function set_evolution_at_level(pokemon, level)
	pokemon.level.evolved = level
	storage.set_evolution_at_level(M.get_id(pokemon), level)
end

function M.add_hp_from_levels(pokemon, to_level)
	if not M.get_max_hp_edited(pokemon) and not M.have_ability(pokemon, "Paper Thin") then
		local current = M.get_max_hp(pokemon)
		local hit_dice = M.get_hit_dice(pokemon)
		local con = M.get_attributes(pokemon).CON
		local con_mod = math.floor((con - 10) / 2)
		
		local levels_gained = to_level - M.get_current_level(pokemon)
		local from_hit_dice = math.ceil(hit_dice / 2) * levels_gained
		local from_con_mod = con_mod * levels_gained

		M.set_max_hp(pokemon, current + from_hit_dice + from_con_mod)

		-- Also increase current hp
		local c = M.get_current_hp(pokemon)
		M.set_current_hp(pokemon, c + from_hit_dice + from_con_mod)
	end
end

function M.evolve(pokemon, to_species, level)
	if not M.get_max_hp_edited(pokemon) then
		local current = M.get_max_hp(pokemon)
		local gained = level * 2
		M.set_max_hp(pokemon, current + gained)
		
		-- Also increase current hp
		local c = M.get_current_hp(pokemon)
		M.set_current_hp(pokemon, c + gained)
	end
	set_evolution_at_level(pokemon, level)
	set_species(pokemon, to_species)
end


function M.get_saving_throw_modifier(pokemon)
	local prof = M.get_proficency_bonus(pokemon)
	local b = M.get_attributes(pokemon)
	local saving_throws = pokedex.get_saving_throw_proficiencies(M.get_current_species(pokemon)) or {}
	for _, feat in pairs(M.get_feats(pokemon)) do
		local is_resilient = resilient[feat]
		local got_save = false
		if is_resilient then
			for _, save in pairs(saving_throws) do
				if save == is_resilient then
					got_save = true
				end
			end
			if not got_save then
				table.insert(saving_throws, is_resilient)
			end
		end
	end
	
	local modifiers = {}
	for name, mod in pairs(b) do
		modifiers[name] = math.floor((b[name] - 10) / 2)
	end
	for _, st in pairs(saving_throws) do
		modifiers[st] = modifiers[st] + prof
	end

	return modifiers
end

function M.set_nickname(pokemon, nickname)
	local species = M.get_current_species(pokemon)
	if species ~= nickname then
		pokemon.nickname = nickname
		storage.set_nickname(M.get_id(pokemon), nickname)
	end
end

function M.get_nickname(pokemon)
	return storage.get_nickname(M.get_id(pokemon))
end

function M.get_AC(pokemon)
	local _, AC_UP = M.have_feat(pokemon, "AC Up")
	return pokedex.get_pokemon_AC(M.get_current_species(pokemon)) + natures.get_AC(M.get_nature(pokemon)) + AC_UP
end

function M.get_index_number(pokemon)
	return pokedex.get_index_number(M.get_current_species(pokemon))
end

function M.get_hit_dice(pokemon)
	return pokedex.get_pokemon_hit_dice(M.get_current_species(pokemon))
end

function M.get_pokemon_exp_worth(pokemon)
	local level = M.get_current_level(pokemon)
	local sr = pokedex.get_pokemon_SR(M.get_current_species(pokemon))
	return pokedex.get_pokemon_exp_worth(level, sr)
end

local function round_down(num)
	if num<0 then x=-.4999 else x=.4999 end
	local int, _= math.modf(num+x)
	return int
end

function M.get_catch_rate(pokemon)
	local l = M.get_current_level(pokemon)
	local sr = round_down(pokedex.get_pokemon_SR(M.get_current_species(pokemon)))
	local hp = round_down(M.get_current_hp(pokemon) / 10)
	return 10 + l + sr + hp
end

function M.get_evolution_level(pokemon)
	return pokemon.level.evolved or 0
end

function M.get_sprite(pokemon)
	local species = M.get_current_species(pokemon)
	return pokedex.get_sprite(species)
end

local function level_index(level)
	if level >= 17 then
		return "17"
	elseif level >= 10 then
		return "10"
	elseif level >= 5 then
		return "5"
	else
		return "1"
	end
end

local function get_damage_mod_stab(pokemon, move)
	local modifier = 0
	local damage
	local ab
	local stab = false
	local stab_damage = 0
	local total = M.get_total_attribute

	-- Pick the highest of the moves power
	local total = M.get_attributes(pokemon)
	for _, mod in pairs(move["Move Power"]) do
		if total[mod] then
			modifier = total[mod] > modifier and total[mod] or modifier
		end
	end
	modifier = math.floor((modifier - 10) / 2)

	for _, t in pairs(M.get_type(pokemon)) do
		if move.Type == t and move.Damage then
			stab_damage = M.get_STAB_bonus(pokemon)
			stab = true
		end
	end
	local index = level_index(M.get_current_level(pokemon))
	
	local move_damage = move.Damage
	if move_damage then
		damage = move_damage[index].amount .. "d" .. move_damage[index].dice_max
		if move_damage[index].move then
			damage = damage .. "+" .. (modifier+stab_damage)
		end
		ab = modifier + M.get_proficency_bonus(pokemon)
	end
	return damage, modifier, stab
end	

function M.get_move_data(pokemon, move_name)
	local move = movedex.get_move_data(move_name)
	local dmg, mod, stab = get_damage_mod_stab(pokemon, move)
	
	local move_data = {}
	move_data.damage = dmg
	move_data.stab = stab
	move_data.name = move_name
	move_data.type = move.Type
	move_data.PP = move.PP
	move_data.duration = move.Duration
	move_data.range = move.Range
	move_data.description = move.Description
	move_data.power = move["Move Power"]
	move_data.save = move.Save
	move_data.time = move["Move Time"]
	
	if move_data.damage then
		move_data.AB = mod + M.get_proficency_bonus(pokemon)
	end
	if move_data.save then
		move_data.save_dc = 8 + mod + M.get_proficency_bonus(pokemon)
	end

	return move_data
end

function M.new(data)
	local this = {}
	this.species = {}
	this.species.caught = data.species
	this.species.current = data.species

	this.hp = {}
	this.hp.current = pokedex.get_base_hp(this.species.caught)
	this.hp.max = this.hp.current
	this.hp.edited = false

	this.level = {}
	this.level.caught = pokedex.get_minimum_wild_level(this.species.caught)
	this.level.current = this.level.caught
	this.level.evolved = 0

	this.attributes = {}
	this.attributes.increased = data.attributes or {}

	this.abilities = {}

	this.exp = pokedex.get_experience_for_level(this.level.caught-1)
	
	this.moves = data.moves
	return this
end



return M