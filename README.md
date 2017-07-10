# Schemlib - A Schematics library for Minetest mods

The goal of this library is to help manage buildings and other node-placement related tasks in other mods.
The Mod is a consolidation of TownChest and handle_schematics at the time

Current status: Hacking

Reference implementations: WIP / nothing shiny
  - The NPCF-Builder from my fork (builder_schemlib-branch) use some basics:
  https://github.com/bell07/minetest-npcf/tree/builder_schemlib

License: LGPLv2 oder später

#API
----

##data types (and usual names):
  - node_obj  - object representing a node in plan
  - plan_obj  - object representing a whole plan
  - plan_pos  - a relative position vector used in plan. Note: the relative 0,0,0 in plan will be the placed to the defined world_pos position
  - world_pos - a absolute ("real") position vector in the world

  - plan_node - a abstract node description used in plan till build
  - buildable_node - a enhanced plan node ready for build

  - status
  "new"    - created
  "ready"  - ready for processing
  ??? - custom status possible

  - plan_type - a type of plan to handle different types
    - house
    - lumber

##Plan object
###public class-methods 
  - new(plan_id[,anchor_pos])    - Constructor - create a new plan object with unique plan_id (WIP)
  - get(plan_id)    - get a existing plan object with unique plan_id
  - get_all()       - get a plan list
  - save_all()      - write plan definitions to files in world
  - load_all()      - read all plan definitions from files in world

###public object methods
  - add_node(node_obj, adjustment)  - add a node to plan - if adjustment is given, the min/max and ground_y is calculated
  - get_node(plan_pos)             - get a node from plan (done)
  - del_node(plan_pos)             - delete a node from plan (done)
  - get_node_next_to_pos(plan_pos) - get the nearest node to pos (low-prio)
  - get_node_random()              - get a random existing plan_pos from plan (done)
  - get_chunk_nodes(plan_pos)      - get a list of all nodes from chunk of a pos (done)
  - read_from_schem_file(file)     - read from WorldEdit or mts file (done)
  - get_world_pos(plan_pos[,anchor_pos]) - get a world position for a plan position (done)
  - get_plan_pos(world_pos[,anchor_pos]) - get a plan position for a world position (done)
  - get_buildable_node(plan_pos)   - get a plan node ready to build (done)
  - load_plan()                    - load a plan state from file in world-directory (low-prio) (:scm_data_cache)
  - save_plan()                    - store the current plan to a file in world directory and set them valid (low-prio) (:scm_data_cache)
  - delete_plan()                  - remove the plan from plan_list
  - change_plan_id(new_plan_id)    - change the plan id
  - propose_anchor(world_pos, bool, add_xz, add_y)
                                   - propose anchor pos nearly given world_pos to be placed.
                                     if bool is given true a check will be done to prevent overbuilding of existing structures
                                     additional space to check for all sites can be given by add_xz (default 3) and add_y (default 5)
                                   - returns "false, world_pos" in case of error. The world_pos is the issued not buildable position in this case
  - apply_flood_with_air
       (add_max, add_min, add_top) - Fill a building with air (done)
  - do_add_node(buildable_node)    - Place node to world using "add_node" and remove them from plan (done)
  - do_add_chunk(plan_pos)         - Place a node (done)
  - do_add_chunk_voxel(plan_pos)   - Place a node (done)

##Internals
###private class attributes
  - plan_list - a simple list with all known plans

###private object atributes
####allways loaded in list
  - plan_id    - a id of the plan (=filename)
  - status     - plan status
  - anchor_pos - position vector in world
  - data.nodeinfos      - a list of node information for name_id with counter ({name_orig="abc:dcg",count=1})
  - self.data.nodeinfos_by_orig_name - revert nodeinfos, key is the name_orig, value is the nodeinfo id
  - data.ground_y       - explicit ground adjustment for anchor_pos
  - self.data.groundnode_count - count of nodes found for ground_y determination
  - data.min_pos        - minimal {x,y,z} vector
  - data.max_pos        - maximal {x,y,z} vector

####save the cache data using save_cache()
  - data.nodecount      - count of nodes in scm_data_cache
  - data.scm_data_cache - all plan nodes

####will be rebuild on demand
  - data.prepared_cache - cache of prepared buildable nodes

##Node object
###public class-methods 
  - new(data)    - Constructor - create a new node object with given data
 
