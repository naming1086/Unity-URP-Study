Shader "URP/URPMultiLight"
{
    Properties
    {
        _MainTex ("MainTex Texture", 2D) = "white" {}
        _BaseColor("Base Color",Color)=(1,1,1,1)
        [KeywordEnum(ON,OFF)]_ADD_LIGHT("AddLight",float)=1
    }
    SubShader
    {
        Tags 
        { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque" 
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        CBUFFER_END

        struct a2v
        {
            float4 positionOS : POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord : TEXCOORD;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 texcoord : TEXCOORD;
            float3 WS_N:NORMAL;
            float3 WS_V:TEXCOORD1;
            float3 WS_P:TEXCOORD2;
        };

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        ENDHLSL

        Pass
        {        
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);

                o.WS_N=normalize(TransformObjectToWorldNormal(i.normalOS.xyz));//法线
                o.WS_P=TransformObjectToWorld(i.positionOS.xyz);
                o.WS_V=normalize(_WorldSpaceCameraPos-o.WS_P);//观察方向

                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord)* _BaseColor;                
                
                Light myLight = GetMainLight();
                float3 WS_Light = normalize(myLight.direction);
                float3 WS_Normal = i.WS_N;
                float3 WS_View = i.WS_V;
                float3 WS_Pos= i.WS_P;

                //计算主光源的半兰伯特光照模型
                float4 mainColor = (dot(WS_Light,WS_Normal)*0.5+0.5)*mainTex*float4(myLight.color,1);

                //calcute addLight
                half4 addColor = half4(0,0,0,1);
                #if _ADD_LIGHT_ON
                //定义在lighting库函数的方法 返回一个额外灯光的数量
                int addLightsCount = GetAdditionalLightsCount();
                for(int i=0;i<addLightsCount;i++)
                {
                    //定义在lightling库里的方法 返回一个灯光类型的数据
                    Light addLight = GetAdditionalLight(i,WS_Pos);
                    float3 WS_AddLightDir = normalize(addLight.direction);
                    //计算其它光源的半兰伯特光照模型 累加
                    addColor += (dot(WS_Normal,WS_AddLightDir)*0.5+0.5)*half4(addLight.color,1)*mainTex*addLight.distanceAttenuation*addLight.shadowAttenuation;
                }
                #else
                addColor=half4(0,0,0,1);
                #endif
                return mainColor+addColor;
            }
            ENDHLSL
        }
    }
}
