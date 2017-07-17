# Schemlib - A Schematics library for Minetest mods

The goal of this library is to help manage buildings and other node-placement related tasks in other mods.
The Mod is a consolidation of TownChest and handle_schematics at the time

Current status: Hacking

Reference implementations: WIP / nothing shiny
  - The NPCF-Builder use some basics: https://github.com/stujones11/minetest-npcf/ 
  - My NPCF-Builder (slightly other focus): https://github.com/bell07/minetest-schemlib_builder_npcf

License: LGPLv2

# API
----

## data types (and usual names):
  - node_obj  - object representing a node in plan
  - plan_obj  - object representing a whole plan
  - plan_pos  - a relative position vector used in plan. Note: the relative 0,0,0 in plan will be the placed to the defined world_pos position
  - world_pos - a absolute ("real") position vector in the world

## Plan object
### class-methods
  - plan_obj = schemlib.plan.new([plan_id][,anchor_pos])    - Constructor - create a new plan object

### object methods
  - plan_obj:add_node(plan_pos, node)       - add a node to plan - if adjustment is given, the min/max and ground_y is calculated
  - plan_obj:adjust_building_info(plan_pos, node) - adjust bilding size and ground information
  - plan_obj:get_node(plan_pos)             - get a node from plan
  - plan_obj:del_node(plan_pos)             - delete a node from plan
  - plan_obj:get_random_plan_pos()          - get a random existing plan_pos from plan
  - plan_obj:get_chunk_nodes(plan_pos)      - get a list of all nodes from chunk of a pos
  - plan_obj:read_from_schem_file(file)     - read from WorldEdit or mts file
  - plan_obj:get_world_pos(plan_pos[,anchor_pos]) - get a world position for a plan position
  - plan_obj:get_world_minp([anchor_pos])   - get lowest world position
  - plan_obj:get_world_maxp([anchor_pos])   - get highest world position
  - plan_obj:get_plan_pos(world_pos[,anchor_pos]) - get a plan position for a world position
  - plan_obj:propose_anchor(world_pos, bool, add_xz, add_y)
                                   - propose anchor pos nearly given world_pos to be placed.
                                     if bool is given true a check will be done to prevent overbuilding of existing structures
                                     additional space to check for all sites can be given by add_xz (default 3) and add_y (default 5)
                                   - returns "false, world_pos" in case of error. The world_pos is the issued not buildable position in this case
  - plan_obj:apply_flood_with_air
       (add_max, add_min, add_top) - Fill a building with air
  - plan_obj:do_add_chunk(plan_pos) - Place all nodes for chunk in real world
  - plan_obj:do_add_chunk_voxel(plan_pos)   - Place all nodes for chunk in real world using voxelmanip
  - plan_obj:get_status()          - get the plan status. Returns values are "new", "build" and "finished"
  - plan_obj:set_status(status)    - set the plan status. Created plan is new, allowed new stati are "build" and "finished"
  - plan_obj:load_region(min_world_pos[, max_world_pos]) - Load a Voxel-Manip for faster lookups to the real world

### Hooks
  - plan_obj:on_status()           - if defined, is called from get_plan_status() to get custom updates

### Attributes
  - plan_obj.plan_id    - a id of the plan
  - plan_obj.status     - plan status
  - plan_obj.anchor_pos - position vector in world
  - plan_obj.data.nodeinfos      - a list of node information for name_id with counter (list={pos_hash,...}, count=1})
  - plan_obj.data.ground_y       - explicit ground adjustment for anchor_pos
  - plan_obj.data.nodecount      - count of the nodes in plan
  - plan_obj.data.groundnode_count - count of nodes found for ground_y determination (internal)
  - plan_obj.data.min_pos        - minimal {x,y,z} vector
  - plan_obj.data.max_pos        - maximal {x,y,z} vector

## Node object
### class-methods
  - node_obj = schemlib.plan.new(data)    - Constructor - create a new node object with given data

### object-methods
  - node_obj:get_world_pos() - nodes assigned to plan only
  - node_obj:get_mapped()    - get mapped data for this node as it should be placed - returns a table {name=, param2=, meta=, content_id=, node_def=, final_nod_name=}
    - name, param2, meta   - data used to place node
    - content_id, node_def - game references, VoxelMap ID and registered_nodes definition
    - final_node_name      - if set, the node is not deleted from plan by place(). Contains the node name to be placed at the end. used for replacing by air before build the node
    - world_node_name      - contains the node name currently placed to the world
  - node_obj:place()         - place node to world using "add_node" and remove them from plan
  - node_obj:remove_from_plan() - remove this node from plan
  - node_obj:get_under()     - returns the node under this one if exists in plan
  - node_obj:get_above()     - returns the node above this one if exists in plan

### object-attributes
  - node_obj.name         - original node name without mapping
  - node_obj.data         - table with original param2 / meta / prob

    assigned in plan:add_node(plan_pos, node_obj) method
  - node_obj.plan         - assigned plan
  - node_obj.nodeinfo     - assigned nodeinfo in plan

## Builder NPC AI object
### class-methods
  - npc_ai_obj = schemlib.npc_ai.new(plan_obj, build_distance)    - Constructor - create a new NPC AI handler for this plan. Build distance is the  lenght of npc

### object-methods
  - npc_ai_obj:plan_target_get(npcpos) - search for the next node to build near npcpos
  - npc_ai_obj:place_node(node_obj) - Place the node and remove from plan

    next methods internally used in plan_target_get
  - npc_ai_obj:get_if_buildable(node_obj)  - Check the node_obj if it can be built in the world. Compares if similar node already at the place
  - npc_ai_obj:get_node_rating(node, npcpos) - internally used - rate a node for importance to build at the next
  - npc_ai_obj:prefer_target(npcpos, nodeslist) - Does rating of all nodes in nodeslist and returns the highest rated node

### object-attributes
  - npc_ai_obj.plan            - assigned plan
  - npc_ai_obj.lasttarget_name - name of the last placed node
  - npc_ai_obj.lasttarget_pos  - position of the last placed node
