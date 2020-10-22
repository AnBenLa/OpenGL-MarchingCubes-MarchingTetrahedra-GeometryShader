#version 430
layout (points) in;
layout (triangle_strip, max_vertices = 73) out;

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
layout(binding=4) uniform isampler2D transitionCellClass;
layout(binding=5) uniform isampler2D transitionCellData;
layout(binding=6) uniform isampler2D transitionCellVertexData;

uniform vec3 volume_dimensions;
uniform float iso_value;
uniform float voxel_size;
uniform int lod;
uniform int surface_shift;
uniform int project_transvoxel;
uniform int transition_cell;

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

// see https://math.stackexchange.com/a/100766
vec4 project_onto_plane(vec4 point, vec3 normal, vec4 plane_point){
    float t = (
    dot(normal.x, plane_point.x) - dot(normal.x,point.x) +
    dot(normal.y, plane_point.y) - dot(normal.y,point.y) +
    dot(normal.z,plane_point.z) - dot(normal.z, point.z)) /
    (normal.x*normal.x + normal.y*normal.y + normal.z*normal.z);
    return vec4(point.x + t * normal.x, point.y + t * normal.y, point.z + t * normal.z, 1);
}

vec3 compute_gradient(vec3 in_sampling_pos){
    // the distance is the length of the ray increment
    // this distance was choosen to calculate a more accurate normal
    float distance =  0.1f;
    float x_p_1 = sample_volume(vec4(in_sampling_pos.x + distance, in_sampling_pos.y, in_sampling_pos.z, 1));
    float x_m_1 = sample_volume(vec4(in_sampling_pos.x - distance, in_sampling_pos.y, in_sampling_pos.z, 1));
    float y_p_1 = sample_volume(vec4(in_sampling_pos.x, in_sampling_pos.y + distance, in_sampling_pos.z, 1));
    float y_m_1 = sample_volume(vec4(in_sampling_pos.x, in_sampling_pos.y - distance, in_sampling_pos.z, 1));
    float z_p_1 = sample_volume(vec4(in_sampling_pos.x, in_sampling_pos.y, in_sampling_pos.z + distance, 1));
    float z_m_1 = sample_volume(vec4(in_sampling_pos.x, in_sampling_pos.y, in_sampling_pos.z - distance, 1));
    float d_x = (x_p_1 - x_m_1) * 0.5;
    float d_y = (y_p_1 - y_m_1) * 0.5;
    float d_z = (z_p_1 - z_m_1) * 0.5;
    return normalize(vec3(d_x, d_y, d_z));
}

void process_left_transistion_cell(){
    mat4 mvp = projection * view * model;
    int voxel_size_lod = 2;
    vec4 sample_positions[13];
    sample_positions[0] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[0];
    sample_positions[2] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[2];
    sample_positions[6] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[4];
    sample_positions[8] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * corner[6];

    sample_positions[1] = (sample_positions[0] + sample_positions[2])*0.5f;
    sample_positions[3] = (sample_positions[0] + sample_positions[6])*0.5f;
    sample_positions[5] = (sample_positions[2] + sample_positions[8])*0.5f;
    sample_positions[7] = (sample_positions[6] + sample_positions[8])*0.5f;
    sample_positions[4] = (sample_positions[3] + sample_positions[5])*0.5f;

    sample_positions[9] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * transvoxel_adjust[0];
    sample_positions[10] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * transvoxel_adjust[2];
    sample_positions[11] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * transvoxel_adjust[4];
    sample_positions[12] = gl_in[0].gl_Position + voxel_size_lod * voxel_size * transvoxel_adjust[6];

    int left_index = 0;
    int k = 1;
    float corner_sample[12];

    for (int i = 0; i < 9; i++){
        corner_sample[i] = sample_volume(sample_positions[i]);
        if (corner_sample[i] < iso_value) left_index |= k;
        k = k << 1;
    }
    if (left_index != 0 && left_index != 511){
        int trans_cell_class = texelFetch(transitionCellClass, ivec2(left_index, 0), 0).r;
        int geometry_count = texelFetch(transitionCellData, ivec2(0, trans_cell_class  & 0x7F), 0).r;
        int trans_vertex_count = geometry_count >> 4;
        int trans_triangle_count = geometry_count & 0x0F;

        int trans_vertex_data[12];
        vec4 trans_vertices[16];

        for (int i = 0; i < 12; i++){
            trans_vertex_data[i] = texelFetch(transitionCellVertexData, ivec2(i, left_index), 0).r;
        }

        for (int i = 0; i < trans_vertex_count; i++){

            int vertex = trans_vertex_data[i];
            if (vertex == 0)break;

            int corner_1 = (vertex >> 4) & 0x0F;
            int corner_2 = vertex & 0x0F;

            vec4 a = sample_positions[corner_1];
            vec4 b = sample_positions[corner_2];
            float value_a = corner_sample[corner_1];
            float value_b = corner_sample[corner_2];
            trans_vertices[i] = interpolate_vertex(iso_value, a, b, value_a, value_b);
        }

        for (int i = 0; i < trans_triangle_count * 3;i += 3){
            int a_index = texelFetch(transitionCellData, ivec2(i+1, left_index), 0).r;
            int b_index = texelFetch(transitionCellData, ivec2(i+2, left_index), 0).r;
            int c_index = texelFetch(transitionCellData, ivec2(i+3, left_index), 0).r;

            vec4 vert_a = trans_vertices[a_index];
            vec4 vert_b = trans_vertices[b_index];
            vec4 vert_c = trans_vertices[c_index];

            vec3 a = vert_a.xyz - vert_b.xyz;
            vec3 b = vert_c.xyz - vert_b.xyz;
            vec3 n = abs(normalize(cross(a, b)));
            frag.normal = n;

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

    float transvoxel_size = 0.2f;

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

            if (lod_left == 1){
                transvoxel_adjust[0] = transvoxel_adjust[0] + vec4(transvoxel_size, 0, 0, 0);
                transvoxel_adjust[2] = transvoxel_adjust[2] + vec4(transvoxel_size, 0, 0, 0);
                transvoxel_adjust[4] = transvoxel_adjust[4] + vec4(transvoxel_size, 0, 0, 0);
                transvoxel_adjust[6] = transvoxel_adjust[6] + vec4(transvoxel_size, 0, 0, 0);
                transvoxel = true;
            }

            if (lod_right == 1){
                transvoxel_adjust[1] = transvoxel_adjust[1] + vec4(-transvoxel_size, 0, 0, 0);
                transvoxel_adjust[3] = transvoxel_adjust[3] + vec4(-transvoxel_size, 0, 0, 0);
                transvoxel_adjust[5] = transvoxel_adjust[5] + vec4(-transvoxel_size, 0, 0, 0);
                transvoxel_adjust[7] = transvoxel_adjust[7] + vec4(-transvoxel_size, 0, 0, 0);
                transvoxel = true;
            }

            if (lod_down == 1){
                transvoxel_adjust[0] = transvoxel_adjust[0] + vec4(0, transvoxel_size, 0, 0);
                transvoxel_adjust[1] = transvoxel_adjust[1] + vec4(0, transvoxel_size, 0, 0);
                transvoxel_adjust[4] = transvoxel_adjust[4] + vec4(0, transvoxel_size, 0, 0);
                transvoxel_adjust[5] = transvoxel_adjust[5] + vec4(0, transvoxel_size, 0, 0);
                transvoxel = true;
            }

            if (lod_top == 1){
                transvoxel_adjust[2] = transvoxel_adjust[2] + vec4(0, -transvoxel_size, 0, 0);
                transvoxel_adjust[3] = transvoxel_adjust[3] + vec4(0, -transvoxel_size, 0, 0);
                transvoxel_adjust[6] = transvoxel_adjust[6] + vec4(0, -transvoxel_size, 0, 0);
                transvoxel_adjust[7] = transvoxel_adjust[7] + vec4(0, -transvoxel_size, 0, 0);
                transvoxel = true;
            }

            if (lod_front == 1){
                transvoxel_adjust[0] = transvoxel_adjust[0] + vec4(0, 0, transvoxel_size, 0);
                transvoxel_adjust[1] = transvoxel_adjust[1] + vec4(0, 0, transvoxel_size, 0);
                transvoxel_adjust[2] = transvoxel_adjust[2] + vec4(0, 0, transvoxel_size, 0);
                transvoxel_adjust[3] = transvoxel_adjust[3] + vec4(0, 0, transvoxel_size, 0);
                transvoxel = true;
            }

            if (lod_back == 1){
                transvoxel_adjust[4] = transvoxel_adjust[4] + vec4(0, 0, -transvoxel_size, 0);
                transvoxel_adjust[5] = transvoxel_adjust[5] + vec4(0, 0, -transvoxel_size, 0);
                transvoxel_adjust[6] = transvoxel_adjust[6] + vec4(0, 0, -transvoxel_size, 0);
                transvoxel_adjust[7] = transvoxel_adjust[7] + vec4(0, 0, -transvoxel_size, 0);
                transvoxel = true;
            }


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
    vec4[12] vertex_normals;
    vec4[12] adjusted_vertices;

    for(int i = 0; i < vertex_count; i++){

        int vertex = vertex_data[i];
        if(vertex == 0)break;

        int corner_1 = (vertex >> 4) & 0x0F;
        int corner_2 = vertex & 0x0F;

        vec4 a = gl_in[0].gl_Position + voxel_size_lod * corner[corner_1];
        vec4 b = gl_in[0].gl_Position + voxel_size_lod * corner[corner_2];
        float value_a = corner_sample[corner_1];
        float value_b = corner_sample[corner_2];

        if(surface_shift == 0 || voxel_size_lod == 1){
            vertices[i] = interpolate_vertex(iso_value, a, b, value_a, value_b);
        } else {
            vertices[i] = interpolate_vertex_surface_shifting(iso_value, a, b, value_a, value_b);
        }

        if(transvoxel){
            vec4 a_adj = gl_in[0].gl_Position + voxel_size_lod * voxel_size * transvoxel_adjust[corner_1];
            vec4 b_adj = gl_in[0].gl_Position + voxel_size_lod * voxel_size * transvoxel_adjust[corner_2];

            //TODO verify if corner normals are computed correctly!
            vec3 normal_a = compute_gradient(a.xyz);
            vec3 normal_b = compute_gradient(b.xyz);
            if(value_b < value_a){
                float tmp = value_a;
                value_a = value_b;
                value_b = value_a;
                vec3 tmp_n = normal_a;
                normal_a = normal_b;
                normal_b = normal_a;
            }

            vertex_normals[i] = vec4((normal_a + (normal_b - normal_a)/(value_b - value_a) * (iso_value - value_a)),1);

            adjusted_vertices[i] = interpolate_vertex(iso_value, a_adj, b_adj, value_a, value_b);

            if(lod_left == 1 && transition_cell == 1){
                process_left_transistion_cell();
            }
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
        vec3 n = abs(normalize(cross(a, b)));
        frag.normal = n;

        if(transvoxel && project_transvoxel == 1){
            // get the points of the vertex after adjustment
            vec4 vert_a_adj = adjusted_vertices[a_index];
            vec4 vert_b_adj = adjusted_vertices[b_index];
            vec4 vert_c_adj = adjusted_vertices[c_index];
            // project the vertices onto the triangle plane
            vert_a = project_onto_plane(vert_a_adj, vertex_normals[a_index].xyz, vert_a);
            vert_b = project_onto_plane(vert_b_adj, vertex_normals[b_index].xyz, vert_b);
            vert_c = project_onto_plane(vert_c_adj, vertex_normals[c_index].xyz, vert_c);
        } else if (transvoxel){
            vert_a = adjusted_vertices[a_index];
            vert_b = adjusted_vertices[b_index];
            vert_c = adjusted_vertices[c_index];
        }

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