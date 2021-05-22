// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Custom/Cubemap" 
{
    Properties 
    {
        _Tint ("Tint Color", Color) = (.5, .5, .5, .5)
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
        _Rotation ("Rotation", Range(0, 360)) = 0
        [NoScaleOffset] _Tex ("Cubemap   (HDR)", Cube) = "grey" {}
    }

    SubShader 
    {
        Tags 
        { 
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Background" 
            "RenderType"="Background" 
            "PreviewType"="Skybox" 
        }
        Cull Front 
        ZWrite Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Header.cginc"

        CBUFFER_START(UnityPerMaterial)
        samplerCUBE _Tex;
        half4 _Tex_HDR;
        half4 _Tint;
        half _Exposure;
        float _Rotation;
        float4 _MainTex_ST;
        CBUFFER_END

        struct appdata_t {
            float4 vertex : POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct v2f {
            float4 vertex : SV_POSITION;
            float3 texcoord : TEXCOORD0;
            float3 posWorld : TEXCOORD1;
            float4 screenPos : TEXCOORD2;
            UNITY_VERTEX_OUTPUT_STEREO
        };
        ENDHLSL

        Pass 
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma shader_feature _FOG_ON

            #define unity_ColorSpaceDouble float4(2.0, 2.0, 2.0, 2.0)
            #define UNITY_PI            3.14159265359f
       

            float3 RotateAroundYInDegrees (float3 vertex, float degrees)
            {
                float alpha = degrees *  UNITY_PI/ 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float3(mul(m, vertex.xz), vertex.y).xzy;
            }

            inline half3 DecodeHDR (half4 data, half4 decodeInstructions)
            {
                // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
                half alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;

                // If Linear mode is not supported we can skip exponent part
                #if defined(UNITY_COLORSPACE_GAMMA)
                    return (decodeInstructions.x * alpha) * data.rgb;
                #else
                #   if defined(UNITY_USE_NATIVE_HDR)
                        return decodeInstructions.x * data.rgb; // Multiplier for future HDRI relative to absolute conversion.
                #   else
                        return (decodeInstructions.x * pow(abs(alpha), decodeInstructions.y)) * data.rgb;
                #   endif
                #endif
            }

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                float3 rotated = RotateAroundYInDegrees(v.vertex.xyz, _Rotation);
                o.vertex = TransformObjectToHClip(rotated);
                o.texcoord = v.vertex.xyz;
                o.posWorld = TransformObjectToWorld(v.vertex.xyz);
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 tex = texCUBE (_Tex, i.texcoord);
                half3 c = DecodeHDR (tex, _Tex_HDR);
                c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                c *= _Exposure;
            #ifdef _FOG_ON
                c.xyz = ExponentialHeightFog(c, half3(-i.posWorld.x,i.posWorld.y,-i.posWorld.z));
            #endif
                return half4(c, 1);
            }
            ENDHLSL
        }
    }
}
