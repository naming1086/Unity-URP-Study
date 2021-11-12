//����ϸ���㷨չʾ

Shader "Unlit/SurfaceSubdivision_Test01"
{
    Properties
    {
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1
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
        //��������ϸ�ֵ�ͷ�ļ�
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float _TessellationUniform;
        CBUFFER_END
        
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hs
            #pragma domain ds

            struct a2v
		    {
			    float4 positionOS : POSITION;
		    };

		    struct v2f
		    {
			    float3 positionCS : TEXCOORD0;
		    };

            //�������Ӧ����domain�����У������ռ�ת���ĺ���
            v2f vert(a2v i)
            {
                v2f o;
                //o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.positionCS = i.positionOS.xyz;
                return o;
            }

            struct OutputPatchConstant 
            { 
                //��ͬ��ͼԪ���ýṹ��������ͬ
                //�ò�������Hull Shader����
                //������patch������
                //Tessellation Factor��Inner Tessellation Factor
                float edge[3] : SV_TESSFACTOR;
                float inside  : SV_INSIDETESSFACTOR;
            };

            OutputPatchConstant hsconst (InputPatch<v2f,3> patch)
            {
                //��������ϸ�ֵĲ���
                OutputPatchConstant o;
                o.edge[0] = _TessellationUniform;
                o.edge[1] = _TessellationUniform;
                o.edge[2] = _TessellationUniform;
                o.inside  = _TessellationUniform;
                return o;
            }

            //������ɫ���ṹ�Ķ���
            struct HullOut{
                float3 position : TEXCOORD0;
            };

            [domain("tri")]//ȷ��ͼԪ��quad,triangle��
            [partitioning("integer")]//���edge�Ĺ���equal_spacing,fractional_odd,fractional_even
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]      //��ͬ��ͼԪ���Ӧ��ͬ�Ŀ��Ƶ�
            [patchconstantfunc("hsconst")]//һ��patchһ���������㣬�����������㶼�����������
            [maxtessfactor(64.0f)]
            HullOut hs (InputPatch<v2f,3> patch,uint id : SV_OutputControlPointID){
                //����hullshaderV����
                HullOut hout;
                hout.position=patch[id].positionCS;
                return hout;
            }

            struct DomainOut
            {
                float4 position:SV_POSITION;    
            };

            [domain("tri")]//ͬ����Ҫ����ͼԪ
            DomainOut ds (OutputPatchConstant tessFactors, const OutputPatch<HullOut,3> patch,float3 bary :SV_DOMAINLOCATION)
            //bary:��������
            {
                DomainOut dout;
                float3 p = patch[0].position*bary.x + patch[1].position*bary.y + patch[2].position*bary.z;
                dout.position=TransformObjectToHClip(p.xyz);
                return dout;
            }

            float4 frag (DomainOut i) : SV_Target
            {
                return float4(1.0,1.0,1.0,1.0);
            }
            ENDHLSL
        }
    }
}
