Shader "URP/URPShadowCaster"
{
    Properties
    {
        _MainTex ("Base Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        _Gloss("Gloss",Range(10,300))=50
        [KeywordEnum(ON,OFF)]_CUT("CUT",float)=1
        _Cutoff("Cutoff",Range(0,1))=1
        [KeywordEnum(ON,OFF)]_ADD_LIGHT("AddLight",float)=1
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

        #pragma shader_feature_local _CUT_ON
        #pragma shader_feature_local _ADD_LIGHT_ON

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;//ST = Sampler Texture 采样器纹理
        half4 _BaseColor;
        float _Cutoff;
        float _Gloss;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v//这就是a2v 应用阶段传递模型给顶点着色器的数据
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord : TEXCOORD;
        };

        struct v2f//这就是v2f 顶点着色器传递给片元着色器的数据
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD;
            #ifdef _MAIN_LIGHT_SHADOWS
            float4 shadowcoord:TEXCOORD1;
            #endif
            float3 WS_P:TEXCOORD2;
            float3 WS_N:TEXCOORD3;
            float3 WS_V:TEXCOORD4;
        };

        ENDHLSL

        Pass
        {        
            Tags
            {
                "LightMode"="UniversalForward"
                "RenderType"="TransparentCutout"
                "Queue"="AlphaTest"
            }
            Cull off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_VERTEX_ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);

                o.WS_P = TransformObjectToWorld(i.positionOS.xyz);

                #ifdef _MAIN_LIGHT_SHADOWS//关键字判断，如果没有定义，则不执行
                o.shadowcoord = TransformWorldToShadowCoord(o.WS_P);
                #endif

                o.WS_V = normalize(_WorldSpaceCameraPos - o.WS_P);
                o.WS_N = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));

                return o;
            }

            half4 frag(v2f i):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*_BaseColor;
                #ifdef _CUT_ON
                clip(mainTex.a - _Cutoff);
                #endif
                float3 NormalWS = i.WS_N;
                float3 PositionWS = i.WS_P;
                float3 viewDir=i.WS_V;
                //main light
                #ifdef _MAIN_LIGHT_SHADOWS
                Light myLight = GetMainLight(i.shadowcoord);
                #else
                Light myLight = GetMainLight();
                #endif

                half4 mainColor = (dot(normalize(myLight.direction.xyz),NormalWS)*0.5+0.5)*half4(myLight.color,1);
                mainColor += pow(max(dot(normalize(viewDir+normalize(myLight.direction.xyz)),NormalWS),0),_Gloss);
                mainColor*=myLight.shadowAttenuation;

                //addLights
                half4 addColor = half4(0,0,0,1);
                #ifdef _ADD_LIGHT_ON
                int addLightCount=GetAdditionalLightsCount();
                for(int t=0;t<addLightCount;t++)
                {
                    Light addLight = GetAdditionalLight(t,PositionWS);
                    //额外灯光就只计算一下半兰伯特模型（高光没计算，性能考虑）
                    addColor += (dot(normalize(addLight.direction),NormalWS*0.5+0.5)*half4(addLight.color,1)*addLight.shadowAttenuation*addLight.distanceAttenuation);
                }
                #endif
                return mainTex*(mainColor+addColor);
            }
            ENDHLSL  //ENDCG
        }
        //UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        Pass
        {
            //该pass只把主灯光空间的深度图写到了shadowmap里  addlight灯光空间目前没有写进去 导致模型无法投射addlight的阴影 但是整shader可以接受addlight的阴影
            //官方的
            Tags
            {
                "LightMode"="ShadowCaster"
            }
            HLSLPROGRAM
            #pragma vertex vertshadow
            #pragma fragment fragshadow

            half3 _LightDirection;
            v2f vertshadow(a2v i)
            {
                v2f o;
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                float3 WS_Pos = TransformObjectToWorld(i.positionOS.xyz);
                Light mainLight = GetMainLight();
                float3 WS_Normal = TransformObjectToWorldNormal(i.normalOS.xyz);
                //ApplyShadowBias(世界坐标，模型的世界法线，灯光方向) 获取特殊的裁剪空间的坐标
                o.positionCS = TransformObjectToHClip(ApplyShadowBias(WS_Pos,WS_Normal,_LightDirection));
                //根据是否进行了Z反向（比如unity编辑器下是DX11，是有Z反向的），来取z值和w值*近裁剪面两者之间取最小值；
                //若未Z反向则取最大值。这样得到的Z值再传递给GPU流水线下一个工位。
                #if UNITY_REVERSED_Z
                o.positionCS.z = min(o.positionCS.z,o.positionCS.w*UNITY_NEAR_CLIP_VALUE);
                #else
                o.positionCS.z = max(o.positionCS.z,o.positionCS.w*UNITY_NEAR_CLIP_VALUE);
                #endif
                return o;
            }

            half4 fragshadow(v2f i):SV_Target
            {
                #ifdef _CUT_ON
                float alpha = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord).a;
                clip(alpha-_Cutoff);
                #endif
                return 0;
            }
            ENDHLSL       
		}
    }
}
