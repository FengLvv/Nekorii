using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu( "Custom/GasVolume" )]
[SupportedOnRenderPipeline]
public class GasVolume : VolumeComponent, IPostProcessComponent {
	//定义shader要用的参数
	public ObjectParameter<BoxCollider> gasVolumeBoundingBox = new ObjectParameter<BoxCollider>( null );

	[ExecuteAlways]
	public bool IsActive() {
		return true;
	}
	public bool IsTileCompatible() {
		return false;
	}
}