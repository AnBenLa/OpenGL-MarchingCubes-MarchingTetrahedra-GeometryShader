#version 430
layout (points) in;
layout (triangle_strip, max_vertices = 40) out;

out fData
{
    vec3 position;
    vec3 normal;
    vec4 color;
}frag;

layout(binding=0) uniform sampler3D volume;
layout(binding=1) uniform isampler2D edgeTable;
layout(binding=2) uniform isampler2D triTable;

uniform vec3 volume_dimensions;
uniform float iso_value;
uniform float voxel_size;
uniform int lod;
uniform int surface_shift;

uniform mat4 view;
uniform mat4 projection;
uniform mat4 model;
uniform vec3 camera_position;

vec4[8] corner = {
vec4(0, 0, 1, 0),
vec4(1, 0, 1, 0),
vec4(1, 0, 0, 0),
vec4(0, 0, 0, 0),

vec4(0, 1, 1, 0),
vec4(1, 1, 1, 0),
vec4(1, 1, 0, 0),
vec4(0, 1, 0, 0) };

// here the 6 different tetrahedrons are defined
// i.e. the tetrahedra between the cube vertices 3,0,7,6
// i.e. the tetrahedra betweem the cube vertices 7,0,4,6
int tetrahedrons[6][4] = {
{ 3, 0, 7, 6 },
{ 4, 0, 7, 6 },
{ 0, 4, 5, 6 },
{ 5, 6, 1, 0 },
{ 0, 1, 2, 6 },
{ 0, 3, 2, 6 }
};

// given the id of an edge as defined in https://gyazo.com/8ccbba2864de78ed5195693652b6867b find the vertices that create the edge
// i.e. the edge with id 0 is between the vertices 0 and 3 of the current tetrahedra
// i.e. the edge with id 1 is between the vertices 0 and 1 of the current tetrahedra
int tetrahedra_edge_vertex_mapping[6][2] = {
{ 0, 3 },
{ 0, 1 },
{ 0, 2 },
{ 1, 2 },
{ 1, 3 },
{ 2, 3 }
};

// here the edges that create a triangle for the current tetrahedra configuration are specified
// i.e. the configuration with id 1 produces 1 triangle using the edges 0,2,1
int tetrahedra_triangle_map[16][6] = {
{ -1, -1, -1, -1, -1, -1 },
{ 0, 2, 1, -1, -1, -1 },
{ 1, 4, 3, -1, -1, -1 },
{ 4, 0, 2, 4, 2, 3 },
{ 2, 3, 5, -1, -1, -1 },
{ 0, 1, 5, 1, 5, 3 },
{ 1, 2, 5, 1, 5, 4 },
{ 4, 5, 0, -1, -1, -1 },
{ 4, 5, 0, -1, -1, -1 },
{ 1, 2, 5, 1, 5, 4 },
{ 0, 1, 5, 1, 5, 3 },
{ 2, 3, 5, -1, -1, -1 },
{ 4, 0, 2, 4, 2, 3 },
{ 1, 4, 3, -1, -1, -1 },
{ 0, 2, 1, -1, -1, -1 },
{ -1, -1, -1, -1, -1, -1 }
};

// defines which corners make the edge determined by the first index
int edge_vertex_mapping[12][2] = {
{ 0, 1 },
{ 1, 2 },
{ 2, 3 },
{ 0, 3 },
{ 4, 5 },
{ 5, 6 },
{ 6, 7 },
{ 4, 7 },
{ 0, 4 },
{ 1, 5 },
{ 2, 6 },
{ 3, 7 }
};

int lod_function(vec3 voxel_position){
    if (length(camera_position - (model*vec4(voxel_position, 1)).xyz) > 0.5)
        return 2;
    else
        return 1;
}

// has to be done since the texture coordinates are between 0,0,0 and 1,1,1
vec3 texture_position(vec4 position){
    return position.xyz/volume_dimensions;
}

float sample_volume(vec4 position){
    return texture(volume, texture_position(position)).a;
}

vec4 interpolate_vertex(float iso_value, vec4 a, vec4 b, float value_a, float value_b){
    return vec4((a + (iso_value - value_a)*(b - a)/(value_b - value_a)).xyz, 1);
}

vec4 interpolate_vertex_surface_shifting(float iso_value, vec4 a, vec4 b, float value_a, float value_b){
    vec4 c = (a+b)*0.5f;
    float value_c = sample_volume(c);

    if((value_a-iso_value)*(value_c-iso_value)<0){
        return vec4((a + (iso_value - value_a)*(c - a)/(value_c - value_a)).xyz, 1);
    } else if ((value_b-iso_value)*(value_c-iso_value)<0){
        return vec4((b + (iso_value - value_b)*(c - b)/(value_c - value_b)).xyz, 1);
    } else {
        return vec4((a + (iso_value - value_a)*(b - a)/(value_b - value_a)).xyz, 1);
    }
}

int check_for_occupancy(vec3 voxel_pos){
    int k = 1;
    int cube_index = 0;
    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    // this works already
    for (int i = 0; i < 8; i++){
        // scale the voxels according to the voxel size
        float corner_sample = sample_volume(vec4(voxel_pos, 1) + corner[i]);
        if (corner_sample < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }
    return cube_index;
}

void marching_tetracubes(){
    float[8] corner_sample;
    mat4 mvp = projection * view * model;
    int cube_index = 0;

    int voxel_size_lod = 1;

    if (lod == 1){
        // voxel position
        int x = int(gl_in[0].gl_Position.x / voxel_size);
        int y = int(gl_in[0].gl_Position.y / voxel_size);
        int z = int(gl_in[0].gl_Position.z / voxel_size);

        // base voxel position
        float x_base = (x - (x%2)) * voxel_size;
        float y_base = (y - (y%2)) * voxel_size;
        float z_base = (z - (z%2)) * voxel_size;

        // check for voxel size / lod
        voxel_size_lod = lod_function(vec3(x_base, y_base, z_base));

        // check if voxel is covered
        // if covered return;
        if (voxel_size_lod == 2 && (x % 2 == 1 || y % 2 == 1 || z % 2 == 1)){
            return;
        }
    }

    // store the corner values to avoid recomputation
    for (int i = 0; i < 8; i++){
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + voxel_size_lod * corner[i]);
    }

    // for each tetrahedron
    for (int i = 0; i < 6; ++i){
        cube_index = 0;
        int k = 1;
        // check all 4 corners of the current tetrahedron
        for (int j = 0; j < 4; ++j){
            if (corner_sample[tetrahedrons[i][j]] < iso_value) cube_index |= k;
            k = k << 1;
        }

        // for the current tetrahedra configuration look up the edges that create a triangle
        for (int k = 0; tetrahedra_triangle_map[cube_index][k] != -1 && k < 6; k += 3){

            // the edges are indexed according to the image here: https://gyazo.com/8ccbba2864de78ed5195693652b6867b
            // the triangle table was created using this scheme
            // i.e. for configuration 1 or 0001 the edges 1,2 abd 0 create a triangle
            // the edge 1 is between vertices 0 and 1 of the current tetrahedra
            // the edge 2 is between vertices 0 and 2 of the current tetrahedra
            // the edge 0 is between vertices 0 and 3 of the current tetrahedra
            int edges [3] = { tetrahedra_triangle_map[cube_index][k],
            tetrahedra_triangle_map[cube_index][k + 1],
            tetrahedra_triangle_map[cube_index][k + 2] };
            vec4 vertices [3];

            for (int l = 0; l < 3; ++l){
                // here the vertex indices of the current tetrahedra for the edge_0 are selected
                // the information for this is stored in tetrahedra_edge_vertex_mapping
                // the edge 0 i.e. is between the vertices 0 and 3 of the tetrahedra
                // the edge 1 i.e. is between the vertices 0 and 1 of the tetrahedra
                int edge_a_index = tetrahedra_edge_vertex_mapping[edges[l]][0];
                int edge_b_index = tetrahedra_edge_vertex_mapping[edges[l]][1];

                // here the actual index inside the cube is looked up
                // i.e. the vertex with index 0 in the tetrahedra with index 0 corresponds to the vertex with id 3 in the cube
                int edge_a_actual_index = tetrahedrons[i][edge_a_index];
                int edge_b_actual_index = tetrahedrons[i][edge_b_index];

                // the position of the edge vertices is then being computed
                vec4 vertex_a = gl_in[0].gl_Position + voxel_size_lod * corner[edge_a_actual_index];
                vec4 vertex_b = gl_in[0].gl_Position + voxel_size_lod * corner[edge_b_actual_index];

                // the iso-values of the vertices is the looked up
                float vertex_a_value = corner_sample[edge_a_actual_index];
                float vertex_b_value = corner_sample[edge_b_actual_index];

                if(surface_shift == 0 || voxel_size_lod == 1){
                    vertices[l] = model * interpolate_vertex(iso_value, vertex_a, vertex_b, vertex_a_value, vertex_b_value);
                } else {
                    vertices[l] = model * interpolate_vertex_surface_shifting(iso_value, vertex_a, vertex_b, vertex_a_value, vertex_b_value);
                }

                //vertices[l] = model * interpolate_vertex(iso_value, vertex_a, vertex_b, vertex_a_value, vertex_b_value);
            }

            vec3 a = vertices[0].xyz - vertices[1].xyz;
            vec3 b = vertices[0].xyz - vertices[2].xyz;
            // TODO: this seems to be working incorrectly!
            frag.normal = abs(normalize(cross(a, b)));

            for (int l = 0; l < 3; ++l){
                gl_Position = projection * view * vertices[l];
                frag.position = vertices[l].xyz;
                frag.color = vertices[l];
                EmitVertex();
            }
            EndPrimitive();
        }
    }
}

void main() {
    // scale the voxels according to the voxel size
    for (int i = 0; i < 8; ++i)
    corner[i] = voxel_size * corner[i];

    marching_tetracubes();
}