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
layout(binding=1) uniform isampler2D cellClass;
layout(binding=2) uniform isampler2D cellData;
layout(binding=3) uniform isampler2D vertexData;

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
vec4(0, 0, 0, 0),
vec4(1, 0, 0, 0),
vec4(0, 1, 0, 0),
vec4(1, 1, 0, 0),

vec4(0, 0, 1, 0),
vec4(1, 0, 1, 0),
vec4(0, 1, 1, 0),
vec4(1, 1, 1, 0) };

vec4[8] transvoxel_adjust = {
vec4(0, 0, 0, 0),
vec4(1, 0, 0, 0),
vec4(0, 1, 0, 0),
vec4(1, 1, 0, 0),

vec4(0, 0, 1, 0),
vec4(1, 0, 1, 0),
vec4(0, 1, 1, 0),
vec4(1, 1, 1, 0) };

int lod_function(vec3 voxel_position){
    if (length(vec3(0, 0, 0)/*camera_position*/ - (model*vec4(voxel_position, 1)).xyz) > 0.5)
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
    }
    return vec4((b + (iso_value - value_b)*(c - b)/(value_c - value_b)).xyz, 1);
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


void marching_cubes(){
    float[8] corner_sample;
    mat4 mvp = projection * view * model;
    int cube_index = 0;
    int voxel_size_lod = 1;

    bool transvoxel = false;

    //LOD configurations of neightbours
    int lod_left = 2;
    int lod_right = 2;
    int lod_down = 2;
    int lod_top = 2;
    int lod_front = 2;
    int lod_back = 2;

    if (lod == 1){
        // voxel position normalized (always integer values after the division by voxel size)
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

        // if we have a larger voxel check if the neighbour voxels are smaller (if so we have a transvoxel)
        if (voxel_size_lod == 2){
            // find neighbour lod
            // TODO might not be correct yet. not sure...
            lod_left = lod_function(vec3(x_base - 2 * voxel_size, y_base, z_base));
            lod_right = lod_function(vec3(x_base + 2 * voxel_size, y_base, z_base));
            lod_down = lod_function(vec3(x_base, y_base - 2 * voxel_size, z_base));
            lod_top = lod_function(vec3(x_base, y_base + 2 * voxel_size, z_base));
            lod_front = lod_function(vec3(x_base, y_base, z_base - 2 * voxel_size));
            lod_back = lod_function(vec3(x_base, y_base, z_base + 2 * voxel_size));



            // the transvoxel adjust is used to determine the final position of the vertices (by interpolation)
            // it is basically just the cube corner array but the cube corner array is needed for the volume sampling so it is not modified
            /*
            if (lod_left == 1){
                transvoxel_adjust[0] = transvoxel_adjust[0] + vec4(0.1, 0, 0, 0);
                transvoxel_adjust[3] = transvoxel_adjust[3] + vec4(0.1, 0, 0, 0);
                transvoxel_adjust[4] = transvoxel_adjust[4] + vec4(0.1, 0, 0, 0);
                transvoxel_adjust[7] = transvoxel_adjust[7] + vec4(0.1, 0, 0, 0);
            }

            if (lod_right == 1){
                transvoxel_adjust[1] = transvoxel_adjust[1] + vec4(-0.1, 0, 0, 0);
                transvoxel_adjust[2] = transvoxel_adjust[2] + vec4(-0.1, 0, 0, 0);
                transvoxel_adjust[5] = transvoxel_adjust[5] + vec4(-0.1, 0, 0, 0);
                transvoxel_adjust[6] = transvoxel_adjust[6] + vec4(-0.1, 0, 0, 0);
            }

            if (lod_down == 1){
                transvoxel_adjust[0] = transvoxel_adjust[0] + vec4(0, 0.1, 0, 0);
                transvoxel_adjust[1] = transvoxel_adjust[1] + vec4(0, 0.1, 0, 0);
                transvoxel_adjust[2] = transvoxel_adjust[2] + vec4(0, 0.1, 0, 0);
                transvoxel_adjust[3] = transvoxel_adjust[3] + vec4(0, 0.1, 0, 0);
            }

            if (lod_top == 1){
                transvoxel_adjust[4] = transvoxel_adjust[4] + vec4(0, -0.1, 0, 0);
                transvoxel_adjust[5] = transvoxel_adjust[5] + vec4(0, -0.1, 0, 0);
                transvoxel_adjust[6] = transvoxel_adjust[6] + vec4(0, -0.1, 0, 0);
                transvoxel_adjust[7] = transvoxel_adjust[7] + vec4(0, -0.1, 0, 0);
            }

            if (lod_front == 1){
                transvoxel_adjust[2] = transvoxel_adjust[2] + vec4(0, 0, 0.1, 0);
                transvoxel_adjust[3] = transvoxel_adjust[3] + vec4(0, 0, 0.1, 0);
                transvoxel_adjust[6] = transvoxel_adjust[6] + vec4(0, 0, 0.1, 0);
                transvoxel_adjust[7] = transvoxel_adjust[7] + vec4(0, 0, 0.1, 0);
            }

            if (lod_back == 1){
                transvoxel_adjust[0] = transvoxel_adjust[0] + vec4(0, 0, -0.1, 0);
                transvoxel_adjust[1] = transvoxel_adjust[1] + vec4(0, 0, -0.1, 0);
                transvoxel_adjust[4] = transvoxel_adjust[4] + vec4(0, 0, -0.1, 0);
                transvoxel_adjust[5] = transvoxel_adjust[5] + vec4(0, 0, -0.1, 0);
            }
            */


        }


    }

    // calculate lod of neighbouring voxels
    //neighbour_lod_1 = calculate_current_lod(gl_in[0].gl_Position + vec3(1,0,0));
    //neighbour_lod_2 = calculate_current_lod(gl_in[0].gl_Position + vec3(1,1,0));
    // adapt cube according to transvoxel

    int k = 1;

    // sample the volume at each corner and store the result in the corner sample array
    // compute the index of the cube that will define which triangles will be generated
    // this works already
    for (int i = 0; i < 8; i++){
        // scale the voxels according to the voxel size
        corner_sample[i] = sample_volume(gl_in[0].gl_Position + voxel_size_lod * corner[i]);
        if (corner_sample[i] < iso_value) cube_index |= k;
        // do a bit shift in order to multiply with 2 faster
        k = k << 1;
    }

    //get table data
    int cell_class = texelFetch(cellClass, ivec2(cube_index, 0), 0).r;
    int geometry_count = texelFetch(cellData, ivec2(0, cell_class), 0).r;
    int vertex_count = geometry_count >> 4;
    int triangle_count = geometry_count & 0x0F;

    int vertex_data[12];
    for(int i = 0; i < 12; i++){
        vertex_data[i] = texelFetch(vertexData, ivec2(i, cube_index), 0).r;
    }

    vec4[12] vertices;
    for(int i = 0; i < vertex_count; i++){

        int vertex = vertex_data[i];
        if(vertex == 0)break;

        int corner_1 = (vertex >> 4) & 0x0F;
        int corner_2 = vertex & 0x0F;

        vec4 a = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[corner_1];
        vec4 b = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[corner_2];
        float value_a = sample_volume(a);
        float value_b = sample_volume(b);
        if(surface_shift == 0 || voxel_size_lod == 1){
            vertices[i] = interpolate_vertex(iso_value, a, b, value_a, value_b);
        } else {
            vertices[i] = interpolate_vertex_surface_shifting(iso_value, a, b, value_a, value_b);
        }
    }

    //generate triangles
    for(int i = 0; i < triangle_count * 3;i += 3){
        int a_index = texelFetch(cellData, ivec2(i+1, cell_class), 0).r;
        int b_index = texelFetch(cellData, ivec2(i+2, cell_class), 0).r;
        int c_index = texelFetch(cellData, ivec2(i+3, cell_class), 0).r;

        vec4 vert_a = vertices[a_index];
        vec4 vert_b = vertices[b_index];
        vec4 vert_c = vertices[c_index];

        vec3 a = vert_a.xyz - vert_b.xyz;
        vec3 b = vert_c.xyz - vert_b.xyz;
        frag.normal = abs(normalize(cross(a, b)));

        gl_Position = mvp * vert_a;
        frag.position = (model * vert_a).xyz;
        frag.color = model * vert_a;
        EmitVertex();

        gl_Position = mvp * vert_b;
        frag.position = (model * vert_b).xyz;
        frag.color = model * vert_b;
        EmitVertex();

        gl_Position = mvp * vert_c;
        frag.position = (model * vert_c).xyz;
        frag.color = model * vert_c;
        EmitVertex();
        EndPrimitive();
    }
}


void main() {
    // scale the voxels according to the voxel size
    for (int i = 0; i < 8; ++i)
    corner[i] = voxel_size * corner[i];

    marching_cubes();
}