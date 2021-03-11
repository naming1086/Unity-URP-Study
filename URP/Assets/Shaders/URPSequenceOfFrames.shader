Shader "URP/URPSequenceOfFrames"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _Sheet("Sheet",Vector)=(1,1,1,1)
        _FrameRate("FrameRate",float)=25
        [KeywordEnum(LOCK_Z,FREE_Z)]_Z_STAGE("Z_Stage",float)=1//定义一个是否锁定Z轴
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent" 
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half4 _Sheet;
        float _FrameRate;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

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
        };

        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _Z_STAGE_LOCK_Z
            #pragma shader_feature_local _Z_TEST
            v2f vert (a2v i)
            {
                v2f o;
                //先构建一个新的的Z轴朝向相机的坐标系，这时我们需要在模型空间下计算新的坐标系的三个坐标基
                //由于三个坐标基两两垂直，故只需要计算2个即可叉乘得到第三个坐标基
                //先计算新坐标系的Z轴
                float3 newZ = TransformWorldToObject(_WorldSpaceCameraPos);//获得模型空间的相机坐标作为新坐标的Z轴
                //判断是否开启了锁的Z轴
                #ifdef _Z_STAGE_LOCK_Z
                newZ.y = 0;
                #endif
                newZ = normalize(newZ);
                //根据Z的位置去判断x的方向
                float3 newX = abs(newZ.y)<0.99 ? cross(float3(0,1,0),newZ) : cross(newZ,float3(0,0,1));
                newX = normalize(newX);

                float3 newY = cross(newZ,newX);
                newY = normalize(newY);
                float3x3 Matrix = {newX,newY,newZ};//这里应该取矩阵的逆 但是HLSL没有取逆矩阵的函数
                
                float3 newPos = mul(i.positionOS.xyz,Matrix);//故在mul函数里进行右乘 等同于左乘矩阵的逆（正交矩阵的转置等于逆）

                o.positionCS = TransformObjectToHClip(newPos);
                o.texcoord = TRANSFORM_TEX(i.texcoord, _MainTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 uv;//小方块uv
                uv.x = i.texcoord.x/_Sheet.x+frac(floor(_Time.y*_FrameRate)/_Sheet.x);
                uv.y = i.texcoord.y/_Sheet.y+1-frac(floor(_Time.y*_FrameRate/_Sheet.x)/_Sheet.y);
                return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv);
            }
            ENDHLSL 
        }
    }
}
