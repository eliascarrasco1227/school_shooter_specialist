/**
* Name: schoolshootingspecialist
* Based on the internal empty template. 
* Author: eacg2
* Tags: 
*/

model abp

global {
	int INITIAL_STUDENTS <- 20;
    int total_hunted <- INITIAL_STUDENTS; // Total students
    int remaining_hunted <- INITIAL_STUDENTS;
    int survived_hunted <- 0;
    
    bool student_died <- false;  // Nueva variable para rastrear muerte de estudiantes
    file icon_player <- file("../includes/player2.png");
    file icon_exit <- file("../includes/exit2.png");
    file icon_shooter <- file("../includes/enemy.jpg");
    file icon_dead <- file("../includes/dead.jpg");

    list<point> used_locations <- [];
    //list<float> directions <- [0.0, 90.0, 180.0, 270.0];

    predicate chase_desire <- new_predicate("chase", true);
    predicate survive <- new_predicate("survive", true);
    predicate wander_desire <- new_predicate("wander", true);
    predicate transfer_desire <- new_predicate("change_classroom", true);
    predicate immediate_evacuation <- new_predicate("immediate_evacuation", true);

    init {
        create classroom_area number: 5;
        create student number: total_hunted;
        create shooter number: 3;
        create safe_exit number: 3;
        create bullet number: 0;
    }

    reflex update_survival {
        remaining_hunted <- length(student);
        if (remaining_hunted = 0) {
            do pause;
            write "Simulation Complete: " + survived_hunted + " survived out of " + total_hunted;
        }
    }
    
    reflex global_evacuation {
        if (student_died) {
            ask student {
                do remove_intention(wander_desire, true);
                do remove_intention(transfer_desire, true);
                do add_desire(immediate_evacuation);
            }
            student_died <- false;  // Resetear la bandera
        }
    }
}

grid gworld width: 25 height: 25 neighbors: 8 {
    rgb color <- #lightgrey;
}

species classroom_area {
	list<gworld> pieces <- [];
    gworld door_location <- nil;
	
    init {
        gworld place <- one_of(gworld);
        loop while: place.location in used_locations {
            place <- one_of(gworld);
        }
        
        location <- place.location;
        
        used_locations <- used_locations + location;
		
		pieces <- pieces + place;
		
        list<gworld> my_neighbors <- [];
        list<gworld> neighbors_of_neighbors_list <- [];
        ask place {
            my_neighbors <- neighbors;
        }

        // Create classroom pieces around the classroom area
		loop i over: my_neighbors {
			used_locations <- used_locations + i.location; 
			create classroom_piece {
				location <- i.location;
			}
			
			ask i {
				neighbors_of_neighbors_list <- i.neighbors;
			}
			loop j over: neighbors_of_neighbors_list {
				used_locations <- used_locations + j.location; 
				create classroom_piece {
					location <- j.location;
				}
			}
		}

		gworld neighbor <- one_of(my_neighbors);
        // Add a door to the classroom
        create classroom_door {
        	
            location <- neighbor.location;
            
        }
        door_location <- neighbor;
    }

    aspect base {
        draw square(4) color: #white border: #black;
    }
}

species classroom_piece {
    aspect base {
        draw square(4) color: #white border: #black;
    }
}

species classroom_door {
    aspect base {
        draw square(4) color: #brown border: #black;
    }
}

species safe_exit {
    init {
        location <- one_of(gworld).location;
    }

    aspect base {
        draw image(icon_exit) size: {4, 4};
    }
}

species shooter skills: [moving] control: simple_bdi {
    float vision_range <- 20.0;
    student kill_target <- nil;

    init {
        location <- one_of(gworld).location;
        do add_desire(wander_desire);
    }

    perceive target: student in: vision_range {
        student closest_target <- nil;
        float min_distance <- vision_range + 1.0;

        ask student {
            if (!self.is_safe) {
                float current_distance <- self distance_to myself;
                if (current_distance < min_distance) {
                    closest_target <- self;
                    min_distance <- current_distance;
                }
            }
        }

        if (closest_target != nil) {
        	ask myself {
	            kill_target <- closest_target;
	            do remove_intention(wander_desire, true);
	            do add_desire(chase_desire);
	
	            create bullet returns: new_bullet {
	                Origin <- myself;
	                target <- closest_target;
	                location <- myself.location;
	            }
            }
         }
    }

    plan wandering intention: wander_desire {
        gworld hunterPos <- gworld({location.x, location.y});
        list<gworld> my_neighbors <- [];
        ask hunterPos {
            my_neighbors <- neighbors;
        }
        gworld neighbor <- one_of(my_neighbors);
        do goto target: neighbor on: gworld speed: 2.0;
    }

	plan chasing intention: chase_desire priority: 5 {
	    // Check if the target is invalid (dead), or is safe, and abort if true
	    if (kill_target = nil) {
	        do remove_intention(chase_desire, true);
	        do add_desire(wander_desire);
	        return;
	    }
	
	    // Move directly to the target's current location
	    do goto target: kill_target.location on: gworld speed: 2.0;
	    
	    // Fire a bullet if within vision range of the target
/*     if (self distance_to kill_target <= vision_range) {
	        create bullet returns: new_bullet {
	            Origin <- myself;
	            target <- myself.kill_target;
	            location <- myself.location;
	        }
	    }
	*/	
	}

    aspect base {
        draw image(icon_shooter) size: {4, 4};
        
        draw circle(vision_range) color: rgb(255,0,0,50) border: #red;
    }
}

species bullet skills: [moving] {
    shooter Origin;
    student target;
    safe_exit exit;
    float speed <- 5.0;

    reflex move {
        do goto target: target on: gworld speed: speed;
        if (self distance_to target <= 1) {
        	create dead_body {
                location <- myself.location;
            }
            ask target { do die; }
            Origin.kill_target <- nil;
            remaining_hunted <- remaining_hunted - 1;
            do die;
        }
    }

    aspect base {
        draw circle(1) color: #black;
    }
}

species student skills: [moving] control: simple_bdi {
    float vision_range <- 8.0;
    bool is_safe <- false;
	classroom_area current_classroom <- nil;
	
    init {
        classroom_area spawn_classroom <- one_of(classroom_area);
        current_classroom <- spawn_classroom;
        location <- one_of(spawn_classroom.pieces).location;
        do add_desire(wander_desire);
        do add_desire(transfer_desire);
    }

    // React to shooter within vision range
    perceive target: shooter in: vision_range {
    	ask myself{
    		do remove_intention(wander_desire, true);
        	do add_desire(survive);
    	}
    }

    // React to bullet within vision range
    perceive target: bullet in: vision_range {
		ask myself{
    		do remove_intention(wander_desire, true);
        	do add_desire(survive);
    	}
    }

    plan survive intention: survive {
        safe_exit nearest_exit <- nil;
        float min_distance <- 100000.0;

        ask safe_exit {
            float current_distance <- myself distance_to self;
            if (current_distance < min_distance) {
                nearest_exit <- self;
                min_distance <- current_distance;
            }
        }

        if (nearest_exit != nil) {
            do goto target: nearest_exit on: gworld speed: 5.0;
            if (self distance_to nearest_exit <= 1) {
                is_safe <- true;
                do remove_intention(survive, true);
                ask self { do die; }
                ask shooter { if (self.kill_target = myself) { self.kill_target <- nil; } }
                survived_hunted <- survived_hunted + 1;
            }
        } else {
            do remove_intention(survive, true);
            do add_desire(wander_desire);
        }
    }

   /*  plan wandering intention: wander_desire {
        gworld huntedPos <- gworld({location.x, location.y});
        list<gworld> my_neighbors <- [];
        ask huntedPos {
            my_neighbors <- neighbors;
        }
        gworld neighbor <- one_of(my_neighbors);
        do goto target: neighbor on: gworld speed: 1.5;
    }
    */
     // Handle wandering within a classroom
    plan wandering intention: wander_desire {
        list<gworld> classroom_neighbors <- [];
        ask gworld({location.x, location.y}) {
        	if(self.location in myself.current_classroom.pieces){
        		classroom_neighbors <- self.neighbors;
        	}
        }
        if (length(classroom_neighbors) > 0) {
            do goto target: one_of(classroom_neighbors) on: gworld speed: 1.5;
        }
    }

    // Move between classrooms
    plan transfer_desire {
        classroom_area target_classroom <- one_of(classroom_area);
        if (target_classroom != nil) {
            do goto target: target_classroom.door_location on: gworld speed: 2.0;

            if (self distance_to target_classroom.door_location <= 1) {
                current_classroom <- target_classroom;
                location <- one_of(target_classroom.pieces).location;
            }
        }
    }
    
    plan immediate_evac intention: immediate_evacuation priority: 10 {
        safe_exit nearest_exit <- nil;
        float min_distance <- 100000.0;

        ask safe_exit {
            float current_distance <- myself distance_to self;
            if (current_distance < min_distance) {
                nearest_exit <- self;
                min_distance <- current_distance;
            }
        }

        if (nearest_exit != nil) {
            do goto target: nearest_exit on: gworld speed: 5.0;
            if (self distance_to nearest_exit <= 2) {
                is_safe <- true;
                do remove_intention(immediate_evacuation, true);
                survived_hunted <- survived_hunted + 1;
                ask self { do die; }
            }
        }
    }
    
    reflex check_if_dead {
        if (remaining_hunted < INITIAL_STUDENTS) {
            student_died <- true;
        }
    }
    

    aspect base {
        draw  image(icon_player) size: {4, 4};
    }
}

species dead_body {
    aspect base {
        draw image(icon_dead) size: {4, 4};
    }
}

experiment ABPExperiment type: gui {
	float minimum_cycle_duration <- 0.05;
	
    output {
        display map {
            grid gworld border: #black;
            
            species classroom_area aspect: base;
            species classroom_piece aspect: base;
            species classroom_door aspect: base;
            species safe_exit aspect: base;
            species student aspect: base;
            species shooter aspect: base;
            species bullet aspect: base;
            species dead_body aspect: base;
        }
        
        display "Students alive Statistics" {
            chart "Alive inside, outside and dead" type: pie {
                data "Alive inside" value:  length(student) color: #blue;
                data "Dead" value: INITIAL_STUDENTS -  survived_hunted - length(student) color: #black;
                data "Alive outside (survived)" value: survived_hunted color: #green;                
            }
        }
        
        display "Steps Statistics" {
        	chart "Students inside the school in time (steps)" type: series {
        		data "Remaining " value: length(student) color: #blue;
        		
        	}
        }
    }
}

//CAMBIAR TODO: 3. mejorar balas
//CAMBIAR TODO: 4. Cambiar en vez de muerte, disparo
//CAMBIAR TODO: 5. poner la distancia como metrica.
//CAMBIAR TODO: 4. solucionar error




