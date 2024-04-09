using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable, VolumeComponentMenu( "Custom/Screen Space Reflection Param" )]
public class SSRParameter : VolumeComponent, IPostProcessComponent {
	[Header( "SSR" )]
	public IntParameter MarchSteps = new IntParameter( 200, true );
	public FloatParameter DepthTolerance = new FloatParameter( 1f, true );

	[Header( "Blur" )]
	public BoolParameter EnableBlur = new BoolParameter( true, true );
	public IntParameter BlurStepMultiple = new IntParameter( 15, true );
	public ClampedFloatParameter ColorSigma = new ClampedFloatParameter( 0.1f, 0.1f, 5f, true );
	public ClampedFloatParameter SpacialSigma = new ClampedFloatParameter( 1f, 0.5f, 5f, true );

	public bool IsActive() {
		return true;
	}

	public bool IsTileCompatible() {
		return false;
	}
}