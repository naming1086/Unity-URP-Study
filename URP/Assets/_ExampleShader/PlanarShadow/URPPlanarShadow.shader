Shader "URP/URPPlanarShadow"
{
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" { }
        _BaseColor("Base Color",Color) = (1,1,1,1)

        [Header(Shadow)]
        _GroundHeight("_GroundHeight", Float) = 0
        _ShadowColor("_ShadowColor", Color) = (0, 0, 0, 1)
        _ShadowFalloff("_ShadowFalloff", Range(0, 1)) = 0.05
    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half _GroundHeight;
        half4 _ShadowColor;
        half _ShadowFalloff;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        ENDHLSL

        //MainColor Pass
        Pass
        {
            NAME"MainPass"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD;
            };

            struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD;
            };

            v2f vert(a2v v)
            {
                v2f o;
                //在齐次裁剪空间中的坐标
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            };

            half4 frag(v2f i) : SV_TARGET
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _BaseColor;

                return mainTex;
            };
            ENDHLSL
        }

        //阴影pass
        Pass
        {
            Name "PlanarShadowPass"
            Tags{ "LightMode" = "PlanarShadow" }

            //用使用模板测试以保证alpha显示正确
            Stencil
            {
                Ref 0
                Comp equal
                Pass incrWrap
                Fail keep
                ZFail keep
            }

            Cull Off

            //透明混合模式
            Blend SrcAlpha OneMinusSrcAlpha

            //关闭深度写入
            ZWrite off

            //深度稍微偏移防止阴影与地面穿插
            Offset -1,0

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS: POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 vertex: SV_POSITION;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float3 ShadowProjectPos(float3 positionOS)
            {
                float3 positionWS = TransformObjectToWorld(positionOS);

                //灯光方向
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);

                //阴影的世界空间坐标（低于地面的部分不做改变）
                float3 shadowPos;
                shadowPos.y = min(positionWS.y, _GroundHeight);
                shadowPos.xz = positionWS.xz - lightDir.xz * max(0, positionWS.y - _GroundHeight) / lightDir.y;

                return shadowPos;
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                //得到阴影的世界空间坐标
                float3 shadowPos = ShadowProjectPos(input.positionOS.xyz);

                //转换到裁切空间
                output.vertex = TransformWorldToHClip(shadowPos);

                //得到中心点世界坐标
                float3 center = float3(unity_ObjectToWorld[0].w, _GroundHeight, unity_ObjectToWorld[2].w);
                //计算阴影衰减
                float falloff = 1 - saturate(distance(shadowPos, center) * _ShadowFalloff);

                output.color = _ShadowColor;
                output.color.a *= falloff;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return input.color;
            }
            ENDHLSL
        }
    }
}
