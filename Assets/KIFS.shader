Shader "Raymarch/KIFS"
{
	Properties
	{
        // Shader properties
        _Pos ("Position", vector) = (0, 0, 0)
        _Scale ("Scale", float) = 1
        _Ang1 ("Angle 1", float) = 2.
        _Ang2 ("Angle 2", float) = 3.14
        _Color ("Color", vector) = (-0.42, -0.38, -0.19)
        _Shift ("Shift", vector) = (-4., -1., -1.)
	}
	SubShader
	{
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4x4 _CamMat;
            float3 _Pos, _Color, _Shift;
            float2 _Resolution;
            float _Scale, _Ang1, _Ang2;

            #define AMBIENT_OCCLUSION_COLOR_DELTA float3(0.7, 0.7, 0.7)
            #define AMBIENT_OCCLUSION_STRENGTH 0.008
            #define ANTIALIASING_SAMPLES 1
            #define BACKGROUND_COLOR float3(0.6,0.8,1.0)
            #define COL col_fractal
            #define DE de_fractal
            #define DIFFUSE_ENABLED 0
            #define DIFFUSE_ENHANCED_ENABLED 1
            #define FILTERING_ENABLE 0
            #define FOCAL_DIST 1.73205080757
            #define FOG_ENABLED 0
            #define FRACTAL_ITER 20
            #define LIGHT_COLOR float3(1.0,0.95,0.8)
            #define LIGHT_DIRECTION float3(-0.36, 0.8, 0.48)
            #define MAX_DIST 30.0
            #define MAX_MARCHES 1000
            #define MIN_DIST 1e-5
            #define PI 3.14159265358979
            #define SHADOWS_ENABLED 1
            #define SHADOW_DARKNESS 0.7
            #define SHADOW_SHARPNESS 10.0
            #define SPECULAR_HIGHLIGHT 40
            #define SPECULAR_MULT 0.25
            #define SUN_ENABLED 1
            #define SUN_SHARPNESS 2.0
            #define SUN_SIZE 0.004
            #define VIGNETTE_STRENGTH 0.5

            //##########################################
            //   Space folding
            //##########################################
            float4 planeFold(float4 z, float3 n, float d) {
                z.xyz -= 2.0 * min(0.0, dot(z.xyz, n) - d) * n;
                return z;
            }

            float4 sierpinskiFold(float4 z) {
                z.xy -= min(z.x + z.y, 0.0);
                z.xz -= min(z.x + z.z, 0.0);
                z.yz -= min(z.y + z.z, 0.0);
                return z;
            }

            float4 mengerFold(float4 z) {
                float a = min(z.x - z.y, 0.0);
                z.x -= a;
                z.y += a;
                a = min(z.x - z.z, 0.0);
                z.x -= a;
                z.z += a;
                a = min(z.y - z.z, 0.0);
                z.y -= a;
                z.z += a;
                return z;
            }

            float4 boxFold(float4 z, float3 r) {
                z.xyz = clamp(z.xyz, -r, r) * 2.0 - z.xyz;
                return z;
            }

            float4 rotX(float4 z, float s, float c) {
                z.yz = float2(c*z.y + s*z.z, c*z.z - s*z.y);
                return z;
            }

            float4 rotY(float4 z, float s, float c) {
                z.xz = float2(c*z.x - s*z.z, c*z.z + s*z.x);
                return z;
            }

            float4 rotZ(float4 z, float s, float c) {
                z.xy = float2(c*z.x + s*z.y, c*z.y - s*z.x);
                return z;
            }

            float4 rotX(float4 z, float a) {
                return rotX(z, sin(a), cos(a));
            }

            float4 rotY(float4 z, float a) {
                return rotY(z, sin(a), cos(a));
            }

            float4 rotZ(float4 z, float a) {
                return rotZ(z, sin(a), cos(a));
            }

            //##########################################
            //   Primitive DEs
            //##########################################
            float de_sphere(float4 p, float r) {
                return (length(p.xyz) - r) / p.w;
            }

            float de_box(float4 p, float3 s) {
                float3 a = abs(p.xyz) - s;
                return (min(max(max(a.x, a.y), a.z), 0.0) + length(max(a, 0.0))) / p.w;
            }

            float de_tetrahedron(float4 p, float r) {
                float md = max(max(-p.x - p.y - p.z, p.x + p.y - p.z),
                            max(-p.x + p.y + p.z, p.x - p.y + p.z));
                return (md - r) / (p.w * sqrt(3.0));
            }

            float de_capsule(float4 p, float h, float r) {
                p.y -= clamp(p.y, -h, h);
                return (length(p.xyz) - r) / p.w;
            }

            
            //##########################################
            //   Main DEs
            //##########################################
            float de_fractal(float4 p) {
                for (int i = 0; i < FRACTAL_ITER; ++i) {
                    p.xyz = abs(p.xyz);
                    p = rotZ(p, _Ang1);
                    p = mengerFold(p);
                    p = rotX(p, _Ang2);
                    p *= _Scale;
                    p.xyz += _Shift;
                }
                return de_box(p, float3(6.0, 6.0, 6.0));
            }

            float4 col_fractal(float4 p) {
                float3 orbit = float3(0.0, 0.0, 0.0);
                for (int i = 0; i < FRACTAL_ITER; ++i) {
                    p.xyz = abs(p.xyz);
                    p = rotZ(p, _Ang1);
                    p = mengerFold(p);
                    p = rotX(p, _Ang2);
                    p *= _Scale;
                    p.xyz += _Shift;
                    orbit = max(orbit, p.xyz*_Color);
                }
                return float4(orbit, de_box(p, float3(6.0, 6.0, 6.0)));
            }

            //##########################################
            //   Main code
            //##########################################

            //A faster formula to find the gradient/normal direction of the DE(the w component is the average DE)
            //credit to http://www.iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
            float3 calcNormal(float4 p, float dx) {
                const float3 k = float3(1,-1,0);
                return normalize(k.xyy*DE(p + k.xyyz*dx) +
                                 k.yyx*DE(p + k.yyxz*dx) +
                                 k.yxy*DE(p + k.yxyz*dx) +
                                 k.xxx*DE(p + k.xxxz*dx));
            }

            //find the average color of the fractal in a radius dx in plane s1-s2
            float4 smoothColor(float4 p, float3 s1, float3 s2, float dx) {
                return (COL(p + float4(s1,0)*dx) +
                        COL(p - float4(s1,0)*dx) +
                        COL(p + float4(s2,0)*dx) +
                        COL(p - float4(s2,0)*dx))/4;
            }

            float4 ray_march(inout float4 p, float4 ray, float sharpness, float FOVperPixel) {
                float d = DE(p);
    
                float s = 0.0;
                float td = 0.0;
                float min_d = 1.0;
    
                for (; s < MAX_MARCHES; s += 1.0) {
                    //if the distance from the surface is less than the distance per pixel we stop
                    float min_dist = max(FOVperPixel*td, MIN_DIST);
        
                    if (d < min_dist) {
                        s += d / min_dist;
                        break;
                    } else if (td > MAX_DIST) {
                        break;
                    }
        
                    td += d;
                    p += ray * d;
                    min_d = min(min_d, sharpness * d / td);
                    d = DE(p);
                }
                return float4(d, s, td, min_d);
            }

            float4 scene(inout float4 p, inout float4 ray, float vignette, float FOVperPixel) {
                //Trace the ray
                float4 d_s_td_m = ray_march(p, ray, 1.0, FOVperPixel);
                float d = d_s_td_m.x;
                float s = d_s_td_m.y;
                float td = d_s_td_m.z;

                //Determine the color for this pixel
                float4 col = float4(0.0, 0.0, 0.0, 0.0);
                float min_dist = max(FOVperPixel*td, MIN_DIST);
                if (d < min_dist) {
                    //Get the surface normal
                    float3 n = calcNormal(p, min_dist*0.5);
        
                    //find closest surface point, without this we get weird coloring artifacts
                    p.xyz -= n*d;

                    //Get coloring
                    #if FILTERING_ENABLE
                        //sample direction 1, the cross product between the ray and the surface normal, should be parallel to the surface
                        float3 s1 = normalize(cross(ray.xyz, n));
                        //sample direction 2, the cross product between s1 and the surface normal
                        float3 s2 = cross(s1, n);
                        //get filtered color
                        float4 orig_col = clamp(smoothColor(p, s1, s2, min_dist*0.5), 0.0, 1.0);
                    #else
                        float4 orig_col = clamp(COL(p), 0.0, 1.0);
                    #endif
                    col.w = orig_col.w;

                    //Get if this point is in shadow
                    float k = 1.0;
                    #if SHADOWS_ENABLED
                        float4 light_pt = p;
                        light_pt.xyz += n * MIN_DIST * 100;
                        float4 rm = ray_march(light_pt, float4(LIGHT_DIRECTION, 0.0), SHADOW_SHARPNESS, FOVperPixel);
                        k = rm.w * min(rm.z, 1.0);
                    #endif

                    //Get specular
                    #if SPECULAR_HIGHLIGHT > 0
                        float3 reflected = ray.xyz - 2.0*dot(ray.xyz, n) * n;
                        float specular = max(dot(reflected, LIGHT_DIRECTION), 0.0);
                        specular = pow(specular, SPECULAR_HIGHLIGHT);
                        col.xyz += specular * LIGHT_COLOR * (k * SPECULAR_MULT);
                    #endif

                    //Get diffuse lighting
                    #if DIFFUSE_ENHANCED_ENABLED
                        k = min(k, SHADOW_DARKNESS * 0.5 * (dot(n, LIGHT_DIRECTION) - 1.0) + 1.0);
                    #elif DIFFUSE_ENABLED
                        k = min(k, dot(n, LIGHT_DIRECTION));
                    #endif

                    //Don't make shadows entirely dark
                    k = max(k, 1.0 - SHADOW_DARKNESS);
                    col.xyz += orig_col.xyz * LIGHT_COLOR * k;

                    //Add small amount of ambient occlusion
                    float a = 1.0 / (1.0 + s * AMBIENT_OCCLUSION_STRENGTH);
                    col.xyz += (1.0 - a) * AMBIENT_OCCLUSION_COLOR_DELTA;

                    //Add fog effects
                    #if FOG_ENABLED
                        a = td / MAX_DIST;
                        col.xyz = (1.0 - a) * col.xyz + a * BACKGROUND_COLOR;
                    #endif

                    //Return normal through ray
                    ray = float4(n, 0.0);
                } else {
                    //Ray missed, start with solid background color
                    col.xyz += BACKGROUND_COLOR;

                    col.xyz *= vignette;
                    //Background specular
                    #if SUN_ENABLED
                        float sun_spec = dot(ray.xyz, LIGHT_DIRECTION) - 1.0 + SUN_SIZE;
                        sun_spec = min(exp(sun_spec * SUN_SHARPNESS / SUN_SIZE), 1.0);
                        col.xyz += LIGHT_COLOR * sun_spec;
                    #endif
                }

                return col;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 col = fixed3(0, 0, 0);
                float2 screenPos = i.uv;

                // Normalize UV coords.
                float aspect = _Resolution.x / _Resolution.y;

                float2 uv = 2 * screenPos - 1;
                uv.x *= aspect;
    
                float FOVperPixel = 1.0 / max(_Resolution.x, 900.0);
    
                float4 ray = mul(_CamMat, normalize(float4(uv.x, uv.y, -FOCAL_DIST, 0.0)));
    
                float4 position = float4(_Pos, 1);
    
                float vignette = 1.0 - VIGNETTE_STRENGTH * length(screenPos - 0.5);
                float4 col_r = scene(position, ray, vignette, FOVperPixel);
    
                col += col_r.xyz;
    
                return float4(col, 1);
            }
            ENDCG
	    }
    }
}
