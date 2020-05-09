#version 330 core
const int num_spheres = 80;
const float width = 1280;
const float height = 720;
uniform float iTime;
uniform vec4 sp[(num_spheres+2)*2];
uniform sampler2D terrain;
in vec4 gl_FragCoord;
out vec4 fragColor;


const vec3 sun_dir = normalize( vec3( 1.0, 1.10, 1.0 ));
const float maximum_dist = 99999.0;

vec2 water[4] = vec2[4]( normalize(vec2( 0.23, 0.6556  )), 
                        normalize(vec2( 0.83, -0.26  )),
                        normalize(vec2( 0.13, -0.826  )),
                        normalize(vec2( -0.2, 0.55  )));



vec3 water_ripple( vec3 pos ) {
    float intensity = 0.0;
    float intensity2 = 0.0;
    for( int k=0; k< 4; k++ ) {
        float t = pos.x*water[k].x + pos.z*water[k].y;
        t = t*(4.0-(float(k)*0.51013))+iTime;

        float mt = 1.0/(float(k)+1.0);
        intensity += mt*sin(t-0.3*cos(t));
        intensity2 += mt*cos(t-0.3*sin(t));
    }
    return vec3( intensity, 0.0, intensity2 );
}

float ground_plane_intersect( vec3 ray_dir, vec3 origin, float ground, out vec3 pos, out vec3 norm ) {
    if( ray_dir.y >= 0.0 ) {
        return maximum_dist;
    }
    float t = ( ground-origin.y ) /  ray_dir.y; 
    norm = vec3( 0.0, 1.0f, 0.0f );
    pos = origin + ray_dir*t;
    return t;
}


float w_intersect_sphere( float max_t, vec3 ray_dir, vec3 origin, 
    vec3 sphere, float sphere_radius2, int idx_in, 
    out vec3 pos, out vec3 norm, out int idx ) {
   // intersect with sphere 
    vec3 origToSphere = sphere - origin;
    float tCA = dot( origToSphere, ray_dir);
    if( tCA < 0.0 ) {
        // ray center is towards back of ray. cant intsesect
        return max_t;
    } else 
    {
        float dd = length(origToSphere);
        float distToMidpoint2 = dd*dd-tCA*tCA;
        if( distToMidpoint2 > sphere_radius2 ) {
            return max_t;
        } 
        else {
            float thc = sqrt(sphere_radius2-distToMidpoint2);
            float t0 = tCA - thc;           // entry 
            if( t0 < max_t ) {
                pos = origin + t0*ray_dir;
                norm = normalize( pos-sphere);
                idx = idx_in;
                return t0;
            } else {
                return max_t;
            }
        }
    }
}

// For shadows we only care if there was intersection
bool intersects_sphere( vec3 ray_dir, vec3 origin, vec3 sphere, float sphere_radius2 ) {
   // intersect with sphere 
    vec3 origToSphere = sphere - origin;
    float tCA = dot( origToSphere, ray_dir);
    if( tCA < 0.0 ) {
        // ray center is towards back of ray. cant intsesect
        return false;
    } else 
    {
        float dd = length(origToSphere);
        float distToMidpoint2 = dd*dd-tCA*tCA;
        if( distToMidpoint2 > sphere_radius2 ) {
            return false;
        } 
        else {
            return true;
        }
    }
}

float get_height( vec2 pos, out float level, out float type ) {
    vec4 col = texture( terrain, pos/512.0  );
    level = col.x* 5.0;
    type = col.y;
    return col.x*60.0-12.1;
}

void prep_stepper( vec3 delta, vec3 origin,
    out float step_x, out float tDeltaX, out float tMaxX, out vec3 xNormal, 
    out float step_z, out float tDeltaZ, out float tMaxZ, out vec3 zNormal  ) 
{
    // not handling the degenarate cases where numbers become infinity
    if( delta.x > 0.0 ) {
        step_x = 1.0;
        tDeltaX = 1.0 / delta.x;
        tMaxX = tDeltaX * (1.0 - fract(origin.x));
    } else {
        step_x = -1.0;
        tDeltaX = 1.0 / -delta.x;
        tMaxX = tDeltaX * fract(origin.x); 
    }
    if( delta.z > 0.0 ) {
        step_z = 1.0;
        tDeltaZ = 1.0 / delta.z;
        tMaxZ = tDeltaZ * (1.0 - fract(origin.z));
    } else {
        step_z = -1.0;
        tDeltaZ = 1.0 / -delta.z;
        tMaxZ = tDeltaZ * fract(origin.z); 
    }
    xNormal = vec3( -step_x, 0, 0);
    zNormal = vec3( 0, 0, -step_z);

}

// float max3 (vec3 v) {
//   return max (max (v.x, v.y), v.z);
// }

// float min3 (vec3 v) {
//   return min (min (v.x, v.y), v.z);
// }

void intersect_box( vec3 origin, vec3 delta, out float near, out float far ) {
    float tmin = -1000.;
    float tmax = 1000.;
    if( delta.x != 0.0 ) {
        float tx1 = ( 0. - origin.x ) / delta.x;
        float tx2 = ( 512. - origin.x ) / delta.x;

        tmin = max( tmin, min( tx1, tx2 ));
        tmax = min( tmax, max( tx1, tx2 ));
    }
    if( delta.z != 0.0 ) {
        float tz1 = ( 0. - origin.z ) / delta.z;
        float tz2 = ( 512. - origin.z ) / delta.z;

        tmin = max( tmin, min( tz1, tz2 ));
        tmax = min( tmax, max( tz1, tz2 ));
    }

    near = tmin;
    far = tmax;
}

// void intersect_box( vec3 origin, vec3 ray_dir, out float near, out float far ) {
//     vec3 inv_ray_dir = 1.0 / ray_dir;

//     vec3 t0 = ( vec3( 0., -100., 0.) - origin ) * inv_ray_dir;
//     vec3 t1 = ( vec3( 256., 126., 256.) - origin ) * inv_ray_dir;
// //    vec3 t1 = ( vec3( 512., 512., 512.) - origin ) * inv_ray_dir;
//     vec3 tmin = min( t0, t1);
//     vec3 tmax = max( t0, t1);
//     near = max3( tmin);
//     far = min3( tmax);
// }

bool cast_ray( vec3 origin, vec3 dest, out float t, out vec3 col, out vec3 normal, out float refrac, 
out float type ) 
{
    float near_t, far_t;
    vec3 delta = dest - origin;

    intersect_box( origin,delta, near_t, far_t );

    if( far_t < near_t  ) {
        return false;
    }

    float skip_t =  max( 0., near_t );

    origin = origin + skip_t*delta;

    float step_x, tDeltaX, tMaxX;
    vec3 xNormal;
    float step_z, tDeltaZ, tMaxZ;
    vec3 zNormal;

    prep_stepper( delta, origin, step_x, tDeltaX, tMaxX, xNormal, step_z, tDeltaZ, tMaxZ, zNormal  );


    if( isinf( tMaxX ) || isinf( tMaxZ ) ) {
        return false;
    }
    if( isinf( tDeltaX ) || isinf( tDeltaZ ) ) {
        return false;
    }

    float x = floor( origin.x );
    float z = floor( origin.z );
    float y = 0.0;
    float next_y = origin.y;
    float level;
    float old_height = get_height( vec2( x, z ), level, type );
    refrac = 0.0;
    
    for( t=0.0;t<far_t-skip_t;) {
        if(tMaxX < tMaxZ) { 
            t = tMaxX;
            y = origin.y + delta.y * tMaxX;
            tMaxX= tMaxX + tDeltaX; 
            x= x + step_x; 
            normal = xNormal;
        } else 
        { 
            t = tMaxZ;
            y = origin.y + delta.y * tMaxZ;
            tMaxZ= tMaxZ + tDeltaZ; 
            z= z + step_z; 
            normal = zNormal;
        } 
        // check exit height
        if( old_height > y ) {
            col = vec3( level/40., level/40., 1.0);
            if( level <= 2.5 ){
                col = vec3( 0.2, 0.071, .01 );
                refrac = 1.1;
            } else {
                col = vec3( 0.8, 0.01, 0.01 );
                refrac = 1.5;
            }
            normal = vec3( 0, 1.0, 0 );

            // work out precise t ( maybe precision errors when delta.y is near 0)
            t = ( old_height - origin.y ) / delta.y; 
//            t += skip_t;
            return true;
        }

        // check entry height to next pos
        old_height = get_height( vec2( x, z ), level , type);
        if( old_height > y ) {
            if( level >= 3.5 ){
                col = vec3( 0.2, 0.171, 0.01 );
                refrac = 1.5;
            } else {
                col = vec3( 0.2, 0.2, 0.2 );
                refrac =1.5;
            }

            if( type == 1.0 ) {
                float threshold = (0.6335-0.01)*60.0 - 12.1;
                if( y < threshold ) {
                    type = 0.0;
                }
            }
            //t += skip_t;

            return true;
        }
    }
    return false;
}


float fresnel( float n2, vec3 normal, vec3 incident )
{
    // Schlick aproximation
    float r0 = (1.0-n2) / (1.0+n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    float x = 1.0-cosX;
    float ret = r0+(1.0-r0)*x*x*x*x*x;
    return ret;
}

const vec3 absorption_coeff  = vec3( 0.000005, 0.000015, 0.00027 )*15.0;
const vec3 scattering_coeff = vec3( 0.00015, 0.00015, 0.00027 )*15.0;

vec3 extinction( float dist ) {
    return      exp( -dist*( absorption_coeff + scattering_coeff ) );
}

vec3 in_scatter( float dist, float cos_angle ) {
    float rayleigh_scatter = .0003 / 16.0*3.14159* ( 1.0 + cos_angle*cos_angle ); 

    vec3 rayleigh_coeff =         vec3( 1.0 / ( absorption_coeff.x + scattering_coeff.x ) * ( 1.0-exp( -dist*( scattering_coeff.x ) ) ),
                                        1.0 / ( absorption_coeff.y + scattering_coeff.y ) * ( 1.0-exp( -dist*( scattering_coeff.y ) ) ),
                                        1.0 / ( absorption_coeff.z + scattering_coeff.z ) * ( 1.0-exp( -dist*( scattering_coeff.z ) ) ) );

    float mie_g = 0.476;
    vec3 mie_scatter =  vec3( 0.0020, 0.0008, 0.0002 ) * ( 1.0 - mie_g )*( 1.0 - mie_g ) / ( 4.0 * 3.14159 * pow( ( 1.0 + mie_g*mie_g  - 2.0 * mie_g *cos_angle ), 1.5 ) ); 
    float mie_coeff = 20.0 / (  absorption_coeff.x + scattering_coeff.x ) 
                            * ( 1.0-exp( -dist*( scattering_coeff.x ) ) );
    return rayleigh_scatter*rayleigh_coeff+mie_scatter*mie_coeff;
 }


void main()
{
    // calculate normalized screen pos with center at 0,0 extending width/height,1 
    vec2 screen_pos_2d = 2.0*(gl_FragCoord.xy/height) - vec2( width/height, 1.0 );
    // establish the 3d normalized 3d position, camera is at 0,0,0,   ray is towards screen_pos, depth
    vec3 camera_tgt_3d = vec3( screen_pos_2d, -2.0 );
    //vec3 camera_pos_3d = vec3( 0., 0., 0.);       // no need to track as it is at 0,0,0
    float _angle = sp[ 161 ].y;
    mat3 rot_m = mat3( cos(_angle),0,  -sin( _angle ), 
                         0,          1,          0,
                         sin(_angle), 0, cos(_angle) );

    float _angle2 = sp[ 161 ].x;
    mat3 tilt_m = mat3(  1,     0,       0 , 
                        0,     cos(_angle2),-sin( _angle2 ),
                        0,     sin(_angle2), cos(_angle2) );

    float _angle3 = sp[ 161 ].z;
    mat3 roll = mat3(  cos(_angle3),     -sin( _angle3) ,       0 , 
                        sin(_angle3),     cos(_angle3),0 ,
                        0,     0, 1 );


   rot_m = rot_m * tilt_m * roll;

    vec3 camera_translation = sp[160].xyz;
    
    // vec3 origin = rot_m*camera_pos_3d; no need to rotate origin, Its at 0,0,0
    vec3 dest = rot_m*camera_tgt_3d;

    //    origin += camera_translation;
    vec3 origin = camera_translation;
    dest += camera_translation;

    vec3 ray_dir = normalize( dest - origin );

    float contribution = 1.0;
    vec3 final_color = vec3( 0,0,0);

    for( int bounce =2; bounce >0 ; bounce -- ) {
        vec3 new_ray_dir;
        vec3 norm;
        vec3 pos;
        vec3 diffuseCol;
        float refractive_index;
        float reflectance = 0.0;
        int final_idx = -1;
        float current_t = maximum_dist;

        //Harmonize hit flagging 
        for( int idx=0; idx < num_spheres; idx++ ) {
            current_t  =  w_intersect_sphere( current_t, ray_dir, origin, sp[idx*2].xyz, sp[idx*2].w, idx, pos, norm, final_idx);
        }
        if( final_idx != -1 ) {
            // hit a sphere. tentative data
            diffuseCol = sp[final_idx*2+1].xyz;  // vec3( 0.02, .02, 0.02 );
            refractive_index =  sp[final_idx*2+1].w;       // 1.3171;
            reflectance = fresnel( refractive_index, norm, ray_dir);
            new_ray_dir = reflect( ray_dir, norm );
        }
            
        //Check if we hit the sceneary
        vec3 current_dest = origin + ray_dir;
        float grid_t;
        vec3 diffuseCol2;
        vec3 norm2;
        float type;
        //float refractive_index2;
        if( cast_ray(origin, current_dest, grid_t, diffuseCol2, norm2, refractive_index, type ) ) {
            // hit the scenery, if it is closer than the sphere this overrides
            if( grid_t < current_t ) {
                if( type == 1.0 ) {
                    // rethrow ray for holo
                    float threshold = (0.6335-0.01)*60.0-(11.5);
                    vec3 cell_loc = vec3( 130.0+256.0, threshold, 191.0+256.0 );
                    vec3 new_origin = (origin-cell_loc)*512.0;
                    vec3 new_dest = (current_dest-cell_loc)*512.0;
                    float mini_grid_t;
                    if( cast_ray(new_origin, new_dest, mini_grid_t, diffuseCol2, norm2, refractive_index, type ) ) {
                        current_t = grid_t+ mini_grid_t/512.0;
                        diffuseCol = diffuseCol2;
                        diffuseCol.b = diffuseCol.b*2.0;

                        norm = norm2;
                        pos = origin + ray_dir * current_t*0.9999;
                        reflectance = fresnel( refractive_index, norm, ray_dir);
                        new_ray_dir = reflect( normalize( ray_dir ), norm );
                    } else {
                        // nothing was hit. Carry on with previous direction
                        current_t = grid_t *2.02;
                        origin = origin + ray_dir * current_t;
                        continue;
                    }
                } else {
                    current_t = grid_t;
                    diffuseCol = diffuseCol2;
                    norm = norm2;
                    pos = origin + ray_dir * current_t*0.9999;
                    reflectance = fresnel( refractive_index, norm, ray_dir);
                    new_ray_dir = reflect( normalize( ray_dir ), norm );
                }
            }
        }

        vec3 pos2;
        float g_t = ground_plane_intersect( ray_dir, origin , -0.5, pos2, norm2 );
        if( g_t <= current_t ) {
            pos = origin + ray_dir * g_t*0.9999;
            norm = norm2 + water_ripple( pos )*0.01;
            norm = normalize(norm);

            reflectance = fresnel( 1.1, norm, ray_dir);
            new_ray_dir = reflect( ray_dir, norm );
            final_idx = 0;

            //bend and rethrow ray underwater
            vec3 uw_dir = refract( ray_dir, norm, 1.-reflectance);
            float uw_t;
            diffuseCol = vec3( 0.05, 0.05, 0.15 );                
            if( cast_ray(pos, pos+uw_dir*100.0, uw_t, diffuseCol2, norm2, refractive_index, type ) ) {
                diffuseCol += diffuseCol2 * exp( -uw_t*40.0 );//*-0.25 ) ); 
            }
            final_idx = 0;
         } 


        vec3 point_color = vec3( 0, 0, 0 );
        if( current_t >= maximum_dist ) {
            point_color += in_scatter( current_t, dot( sun_dir,ray_dir) );
            final_color += point_color * contribution;
            break;
        }

        // // light the point
        // Is the light shadowed
        bool in_shade = false;
        vec3 sun_pos = pos + sun_dir*5.0;
        if( cast_ray( pos, sun_pos, grid_t, diffuseCol2, norm2, refractive_index, type ) ) 
        {
            in_shade = true;
        }
        if( !in_shade ) 
        {
            for( int idx=0; idx < num_spheres; idx++ ) 
            {
                if( intersects_sphere( sun_dir, pos, sp[idx*2].xyz, sp[idx*2].w ) ) 
                {
                    in_shade = true;
                    break;
                }
            }                
        }

        if( !in_shade)
        {
            vec3 reflectedLight = reflect( -sun_dir, norm );
            vec3 toCamera = -ray_dir;
            float diffuse = dot( sun_dir, norm );

            vec3 halfway = normalize( toCamera + sun_dir );
            float specular = pow( dot( norm, halfway ), 121.0 );
        
            specular = clamp( specular, 0.0, 1.0 );

            vec3 fragDiffuse = diffuseCol * diffuse;
            point_color += vec3(specular,specular,specular) + fragDiffuse;
        } else {
            point_color += diffuseCol* 0.02;
        }
        // attenuate
        point_color *= extinction( current_t );
        point_color += in_scatter( current_t, dot( sun_dir,ray_dir) );

        final_color += point_color * contribution * ( 1.0 - reflectance );
        contribution = contribution * reflectance;
        ray_dir = new_ray_dir;
        origin = pos;

    }
    vec3 fragFinal = pow( final_color, vec3(1.0 / 2.2) );
    fragColor = vec4(fragFinal, 1.0);
}
