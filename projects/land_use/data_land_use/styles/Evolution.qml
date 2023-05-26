<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis hasScaleBasedVisibilityFlag="0" simplifyDrawingHints="1" styleCategories="AllStyleCategories" simplifyAlgorithm="0" version="3.22.14-Białowieża" simplifyLocal="1" readOnly="0" maxScale="0" labelsEnabled="0" simplifyDrawingTol="1" simplifyMaxScale="1" symbologyReferenceScale="-1" minScale="100100">
  <flags>
    <Identifiable>1</Identifiable>
    <Removable>1</Removable>
    <Searchable>1</Searchable>
    <Private>0</Private>
  </flags>
  <temporal limitMode="0" durationField="idobj_mult" endExpression="" fixedDuration="0" mode="0" startExpression="" startField="" enabled="0" accumulate="0" endField="" durationUnit="min">
    <fixedRange>
      <start></start>
      <end></end>
    </fixedRange>
  </temporal>
  <renderer-v2 symbollevels="0" forceraster="0" enableorderby="0" type="RuleRenderer" referencescale="-1">
    <rules key="{702981a3-b35e-4d23-971c-5ba2cf0a1b08}">
      <rule filter="niv4_21 LIKE '1%'" scalemindenom="1000" key="{670aaa7a-ece7-471b-91f9-3f3a2fc248bf}" label="Espaces artificialisés" symbol="0" scalemaxdenom="70000"/>
      <rule filter="niv4_21 LIKE '2%'" scalemindenom="1000" key="{a603dc9e-f39b-4e39-9076-fcb8707f32b3}" label="Espaces agricoles" symbol="1" scalemaxdenom="70000"/>
      <rule filter="(niv4_21 LIKE '3%' OR niv4_21 LIKE '4%' OR niv4_21 LIKE '5%') AND (niv4_18 LIKE '1%' OR niv4_18 LIKE '2%')" scalemindenom="1000" key="{5853aa0b-7ae4-480c-8fd9-db99d0ab58e9}" label="Espaces naturels, zones humides et espaces en eau" symbol="2" scalemaxdenom="70000"/>
      <rule filter="niv4_21 LIKE '1%'" scalemindenom="70000" key="{01dc1c3e-0643-4680-8d09-f6d10475d730}" label="Espaces artificialisés" symbol="3" scalemaxdenom="300000"/>
      <rule filter="niv4_21 LIKE '2%'" scalemindenom="70000" key="{ea925ec4-25d1-4d7e-97bc-2be29f2e2925}" label="Espaces agricoles" symbol="4" scalemaxdenom="300000"/>
      <rule filter="(niv4_21 LIKE '3%' OR niv4_21 LIKE '4%' OR niv4_21 LIKE '5%') AND (niv4_18 LIKE '1%' OR niv4_18 LIKE '2%')" scalemindenom="70000" key="{dccc1d40-6fc2-4b32-95db-f70055a21b81}" label="Espaces naturels, zones humides et espaces en eau" symbol="5" scalemaxdenom="300000"/>
    </rules>
    <symbols>
      <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="fill" name="0">
        <data_defined_properties>
          <Option type="Map">
            <Option type="QString" value="" name="name"/>
            <Option name="properties"/>
            <Option type="QString" value="collection" name="type"/>
          </Option>
        </data_defined_properties>
        <layer class="SimpleFill" locked="0" enabled="1" pass="0">
          <Option type="Map">
            <Option type="QString" value="3x:0,0,0,0,0,0" name="border_width_map_unit_scale"/>
            <Option type="QString" value="228,26,28,127" name="color"/>
            <Option type="QString" value="bevel" name="joinstyle"/>
            <Option type="QString" value="0,0" name="offset"/>
            <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
            <Option type="QString" value="Pixel" name="offset_unit"/>
            <Option type="QString" value="0,0,0,255" name="outline_color"/>
            <Option type="QString" value="no" name="outline_style"/>
            <Option type="QString" value="1" name="outline_width"/>
            <Option type="QString" value="Pixel" name="outline_width_unit"/>
            <Option type="QString" value="solid" name="style"/>
          </Option>
          <prop k="border_width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
          <prop k="color" v="228,26,28,127"/>
          <prop k="joinstyle" v="bevel"/>
          <prop k="offset" v="0,0"/>
          <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
          <prop k="offset_unit" v="Pixel"/>
          <prop k="outline_color" v="0,0,0,255"/>
          <prop k="outline_style" v="no"/>
          <prop k="outline_width" v="1"/>
          <prop k="outline_width_unit" v="Pixel"/>
          <prop k="style" v="solid"/>
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
        </layer>
      </symbol>
      <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="fill" name="1">
        <data_defined_properties>
          <Option type="Map">
            <Option type="QString" value="" name="name"/>
            <Option name="properties"/>
            <Option type="QString" value="collection" name="type"/>
          </Option>
        </data_defined_properties>
        <layer class="SimpleFill" locked="0" enabled="1" pass="0">
          <Option type="Map">
            <Option type="QString" value="3x:0,0,0,0,0,0" name="border_width_map_unit_scale"/>
            <Option type="QString" value="255,206,29,127" name="color"/>
            <Option type="QString" value="bevel" name="joinstyle"/>
            <Option type="QString" value="0,0" name="offset"/>
            <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
            <Option type="QString" value="Pixel" name="offset_unit"/>
            <Option type="QString" value="0,0,0,255" name="outline_color"/>
            <Option type="QString" value="no" name="outline_style"/>
            <Option type="QString" value="1" name="outline_width"/>
            <Option type="QString" value="Pixel" name="outline_width_unit"/>
            <Option type="QString" value="solid" name="style"/>
          </Option>
          <prop k="border_width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
          <prop k="color" v="255,206,29,127"/>
          <prop k="joinstyle" v="bevel"/>
          <prop k="offset" v="0,0"/>
          <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
          <prop k="offset_unit" v="Pixel"/>
          <prop k="outline_color" v="0,0,0,255"/>
          <prop k="outline_style" v="no"/>
          <prop k="outline_width" v="1"/>
          <prop k="outline_width_unit" v="Pixel"/>
          <prop k="style" v="solid"/>
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
        </layer>
      </symbol>
      <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="fill" name="2">
        <data_defined_properties>
          <Option type="Map">
            <Option type="QString" value="" name="name"/>
            <Option name="properties"/>
            <Option type="QString" value="collection" name="type"/>
          </Option>
        </data_defined_properties>
        <layer class="SimpleFill" locked="0" enabled="1" pass="0">
          <Option type="Map">
            <Option type="QString" value="3x:0,0,0,0,0,0" name="border_width_map_unit_scale"/>
            <Option type="QString" value="162,249,139,127" name="color"/>
            <Option type="QString" value="bevel" name="joinstyle"/>
            <Option type="QString" value="0,0" name="offset"/>
            <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
            <Option type="QString" value="Pixel" name="offset_unit"/>
            <Option type="QString" value="0,0,0,255" name="outline_color"/>
            <Option type="QString" value="no" name="outline_style"/>
            <Option type="QString" value="1" name="outline_width"/>
            <Option type="QString" value="Pixel" name="outline_width_unit"/>
            <Option type="QString" value="solid" name="style"/>
          </Option>
          <prop k="border_width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
          <prop k="color" v="162,249,139,127"/>
          <prop k="joinstyle" v="bevel"/>
          <prop k="offset" v="0,0"/>
          <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
          <prop k="offset_unit" v="Pixel"/>
          <prop k="outline_color" v="0,0,0,255"/>
          <prop k="outline_style" v="no"/>
          <prop k="outline_width" v="1"/>
          <prop k="outline_width_unit" v="Pixel"/>
          <prop k="style" v="solid"/>
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
        </layer>
      </symbol>
      <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="fill" name="3">
        <data_defined_properties>
          <Option type="Map">
            <Option type="QString" value="" name="name"/>
            <Option name="properties"/>
            <Option type="QString" value="collection" name="type"/>
          </Option>
        </data_defined_properties>
        <layer class="CentroidFill" locked="0" enabled="1" pass="0">
          <Option type="Map">
            <Option type="QString" value="0" name="clip_on_current_part_only"/>
            <Option type="QString" value="0" name="clip_points"/>
            <Option type="QString" value="0" name="point_on_all_parts"/>
            <Option type="QString" value="0" name="point_on_surface"/>
          </Option>
          <prop k="clip_on_current_part_only" v="0"/>
          <prop k="clip_points" v="0"/>
          <prop k="point_on_all_parts" v="0"/>
          <prop k="point_on_surface" v="0"/>
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
          <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="marker" name="@3@0">
            <data_defined_properties>
              <Option type="Map">
                <Option type="QString" value="" name="name"/>
                <Option name="properties"/>
                <Option type="QString" value="collection" name="type"/>
              </Option>
            </data_defined_properties>
            <layer class="SimpleMarker" locked="0" enabled="1" pass="0">
              <Option type="Map">
                <Option type="QString" value="0" name="angle"/>
                <Option type="QString" value="square" name="cap_style"/>
                <Option type="QString" value="255,42,42,255" name="color"/>
                <Option type="QString" value="1" name="horizontal_anchor_point"/>
                <Option type="QString" value="bevel" name="joinstyle"/>
                <Option type="QString" value="circle" name="name"/>
                <Option type="QString" value="0,0" name="offset"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="offset_unit"/>
                <Option type="QString" value="35,35,35,255" name="outline_color"/>
                <Option type="QString" value="solid" name="outline_style"/>
                <Option type="QString" value="0.5" name="outline_width"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="outline_width_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="outline_width_unit"/>
                <Option type="QString" value="diameter" name="scale_method"/>
                <Option type="QString" value="7" name="size"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="size_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="size_unit"/>
                <Option type="QString" value="1" name="vertical_anchor_point"/>
              </Option>
              <prop k="angle" v="0"/>
              <prop k="cap_style" v="square"/>
              <prop k="color" v="255,42,42,255"/>
              <prop k="horizontal_anchor_point" v="1"/>
              <prop k="joinstyle" v="bevel"/>
              <prop k="name" v="circle"/>
              <prop k="offset" v="0,0"/>
              <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="offset_unit" v="Pixel"/>
              <prop k="outline_color" v="35,35,35,255"/>
              <prop k="outline_style" v="solid"/>
              <prop k="outline_width" v="0.5"/>
              <prop k="outline_width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="outline_width_unit" v="Pixel"/>
              <prop k="scale_method" v="diameter"/>
              <prop k="size" v="7"/>
              <prop k="size_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="size_unit" v="Pixel"/>
              <prop k="vertical_anchor_point" v="1"/>
              <data_defined_properties>
                <Option type="Map">
                  <Option type="QString" value="" name="name"/>
                  <Option name="properties"/>
                  <Option type="QString" value="collection" name="type"/>
                </Option>
              </data_defined_properties>
            </layer>
          </symbol>
        </layer>
      </symbol>
      <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="fill" name="4">
        <data_defined_properties>
          <Option type="Map">
            <Option type="QString" value="" name="name"/>
            <Option name="properties"/>
            <Option type="QString" value="collection" name="type"/>
          </Option>
        </data_defined_properties>
        <layer class="CentroidFill" locked="0" enabled="1" pass="0">
          <Option type="Map">
            <Option type="QString" value="0" name="clip_on_current_part_only"/>
            <Option type="QString" value="0" name="clip_points"/>
            <Option type="QString" value="0" name="point_on_all_parts"/>
            <Option type="QString" value="0" name="point_on_surface"/>
          </Option>
          <prop k="clip_on_current_part_only" v="0"/>
          <prop k="clip_points" v="0"/>
          <prop k="point_on_all_parts" v="0"/>
          <prop k="point_on_surface" v="0"/>
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
          <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="marker" name="@4@0">
            <data_defined_properties>
              <Option type="Map">
                <Option type="QString" value="" name="name"/>
                <Option name="properties"/>
                <Option type="QString" value="collection" name="type"/>
              </Option>
            </data_defined_properties>
            <layer class="SimpleMarker" locked="0" enabled="1" pass="0">
              <Option type="Map">
                <Option type="QString" value="0" name="angle"/>
                <Option type="QString" value="square" name="cap_style"/>
                <Option type="QString" value="255,237,42,255" name="color"/>
                <Option type="QString" value="1" name="horizontal_anchor_point"/>
                <Option type="QString" value="bevel" name="joinstyle"/>
                <Option type="QString" value="circle" name="name"/>
                <Option type="QString" value="0,0" name="offset"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="offset_unit"/>
                <Option type="QString" value="35,35,35,255" name="outline_color"/>
                <Option type="QString" value="solid" name="outline_style"/>
                <Option type="QString" value="0.5" name="outline_width"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="outline_width_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="outline_width_unit"/>
                <Option type="QString" value="diameter" name="scale_method"/>
                <Option type="QString" value="7" name="size"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="size_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="size_unit"/>
                <Option type="QString" value="1" name="vertical_anchor_point"/>
              </Option>
              <prop k="angle" v="0"/>
              <prop k="cap_style" v="square"/>
              <prop k="color" v="255,237,42,255"/>
              <prop k="horizontal_anchor_point" v="1"/>
              <prop k="joinstyle" v="bevel"/>
              <prop k="name" v="circle"/>
              <prop k="offset" v="0,0"/>
              <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="offset_unit" v="Pixel"/>
              <prop k="outline_color" v="35,35,35,255"/>
              <prop k="outline_style" v="solid"/>
              <prop k="outline_width" v="0.5"/>
              <prop k="outline_width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="outline_width_unit" v="Pixel"/>
              <prop k="scale_method" v="diameter"/>
              <prop k="size" v="7"/>
              <prop k="size_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="size_unit" v="Pixel"/>
              <prop k="vertical_anchor_point" v="1"/>
              <data_defined_properties>
                <Option type="Map">
                  <Option type="QString" value="" name="name"/>
                  <Option name="properties"/>
                  <Option type="QString" value="collection" name="type"/>
                </Option>
              </data_defined_properties>
            </layer>
          </symbol>
        </layer>
      </symbol>
      <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="fill" name="5">
        <data_defined_properties>
          <Option type="Map">
            <Option type="QString" value="" name="name"/>
            <Option name="properties"/>
            <Option type="QString" value="collection" name="type"/>
          </Option>
        </data_defined_properties>
        <layer class="CentroidFill" locked="0" enabled="1" pass="0">
          <Option type="Map">
            <Option type="QString" value="0" name="clip_on_current_part_only"/>
            <Option type="QString" value="0" name="clip_points"/>
            <Option type="QString" value="0" name="point_on_all_parts"/>
            <Option type="QString" value="0" name="point_on_surface"/>
          </Option>
          <prop k="clip_on_current_part_only" v="0"/>
          <prop k="clip_points" v="0"/>
          <prop k="point_on_all_parts" v="0"/>
          <prop k="point_on_surface" v="0"/>
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
          <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="marker" name="@5@0">
            <data_defined_properties>
              <Option type="Map">
                <Option type="QString" value="" name="name"/>
                <Option name="properties"/>
                <Option type="QString" value="collection" name="type"/>
              </Option>
            </data_defined_properties>
            <layer class="SimpleMarker" locked="0" enabled="1" pass="0">
              <Option type="Map">
                <Option type="QString" value="0" name="angle"/>
                <Option type="QString" value="square" name="cap_style"/>
                <Option type="QString" value="18,201,69,255" name="color"/>
                <Option type="QString" value="1" name="horizontal_anchor_point"/>
                <Option type="QString" value="bevel" name="joinstyle"/>
                <Option type="QString" value="circle" name="name"/>
                <Option type="QString" value="0,0" name="offset"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="offset_unit"/>
                <Option type="QString" value="35,35,35,255" name="outline_color"/>
                <Option type="QString" value="solid" name="outline_style"/>
                <Option type="QString" value="0.5" name="outline_width"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="outline_width_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="outline_width_unit"/>
                <Option type="QString" value="diameter" name="scale_method"/>
                <Option type="QString" value="7" name="size"/>
                <Option type="QString" value="3x:0,0,0,0,0,0" name="size_map_unit_scale"/>
                <Option type="QString" value="Pixel" name="size_unit"/>
                <Option type="QString" value="1" name="vertical_anchor_point"/>
              </Option>
              <prop k="angle" v="0"/>
              <prop k="cap_style" v="square"/>
              <prop k="color" v="18,201,69,255"/>
              <prop k="horizontal_anchor_point" v="1"/>
              <prop k="joinstyle" v="bevel"/>
              <prop k="name" v="circle"/>
              <prop k="offset" v="0,0"/>
              <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="offset_unit" v="Pixel"/>
              <prop k="outline_color" v="35,35,35,255"/>
              <prop k="outline_style" v="solid"/>
              <prop k="outline_width" v="0.5"/>
              <prop k="outline_width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="outline_width_unit" v="Pixel"/>
              <prop k="scale_method" v="diameter"/>
              <prop k="size" v="7"/>
              <prop k="size_map_unit_scale" v="3x:0,0,0,0,0,0"/>
              <prop k="size_unit" v="Pixel"/>
              <prop k="vertical_anchor_point" v="1"/>
              <data_defined_properties>
                <Option type="Map">
                  <Option type="QString" value="" name="name"/>
                  <Option name="properties"/>
                  <Option type="QString" value="collection" name="type"/>
                </Option>
              </data_defined_properties>
            </layer>
          </symbol>
        </layer>
      </symbol>
    </symbols>
  </renderer-v2>
  <customproperties>
    <Option type="Map">
      <Option type="List" name="dualview/previewExpressions">
        <Option type="QString" value="&quot;idobj_mult&quot;"/>
      </Option>
      <Option type="int" value="0" name="embeddedWidgets/count"/>
      <Option name="variableNames"/>
      <Option name="variableValues"/>
    </Option>
  </customproperties>
  <blendMode>0</blendMode>
  <featureBlendMode>0</featureBlendMode>
  <layerOpacity>1</layerOpacity>
  <SingleCategoryDiagramRenderer diagramType="Histogram" attributeLegend="1">
    <DiagramCategory backgroundAlpha="255" barWidth="5" showAxis="1" penColor="#000000" scaleDependency="Area" minScaleDenominator="0" backgroundColor="#ffffff" sizeType="MM" labelPlacementMethod="XHeight" diagramOrientation="Up" direction="0" spacing="5" maxScaleDenominator="1e+08" minimumSize="0" scaleBasedVisibility="0" width="15" rotationOffset="270" enabled="0" height="15" lineSizeScale="3x:0,0,0,0,0,0" penAlpha="255" spacingUnit="MM" spacingUnitScale="3x:0,0,0,0,0,0" opacity="1" sizeScale="3x:0,0,0,0,0,0" penWidth="0" lineSizeType="MM">
      <fontProperties style="" description="Ubuntu,11,-1,5,50,0,0,0,0,0"/>
      <attribute colorOpacity="1" label="" field="" color="#000000"/>
      <axisSymbol>
        <symbol alpha="1" force_rhr="0" clip_to_extent="1" type="line" name="">
          <data_defined_properties>
            <Option type="Map">
              <Option type="QString" value="" name="name"/>
              <Option name="properties"/>
              <Option type="QString" value="collection" name="type"/>
            </Option>
          </data_defined_properties>
          <layer class="SimpleLine" locked="0" enabled="1" pass="0">
            <Option type="Map">
              <Option type="QString" value="0" name="align_dash_pattern"/>
              <Option type="QString" value="square" name="capstyle"/>
              <Option type="QString" value="5;2" name="customdash"/>
              <Option type="QString" value="3x:0,0,0,0,0,0" name="customdash_map_unit_scale"/>
              <Option type="QString" value="MM" name="customdash_unit"/>
              <Option type="QString" value="0" name="dash_pattern_offset"/>
              <Option type="QString" value="3x:0,0,0,0,0,0" name="dash_pattern_offset_map_unit_scale"/>
              <Option type="QString" value="MM" name="dash_pattern_offset_unit"/>
              <Option type="QString" value="0" name="draw_inside_polygon"/>
              <Option type="QString" value="bevel" name="joinstyle"/>
              <Option type="QString" value="35,35,35,255" name="line_color"/>
              <Option type="QString" value="solid" name="line_style"/>
              <Option type="QString" value="0.26" name="line_width"/>
              <Option type="QString" value="MM" name="line_width_unit"/>
              <Option type="QString" value="0" name="offset"/>
              <Option type="QString" value="3x:0,0,0,0,0,0" name="offset_map_unit_scale"/>
              <Option type="QString" value="MM" name="offset_unit"/>
              <Option type="QString" value="0" name="ring_filter"/>
              <Option type="QString" value="0" name="trim_distance_end"/>
              <Option type="QString" value="3x:0,0,0,0,0,0" name="trim_distance_end_map_unit_scale"/>
              <Option type="QString" value="MM" name="trim_distance_end_unit"/>
              <Option type="QString" value="0" name="trim_distance_start"/>
              <Option type="QString" value="3x:0,0,0,0,0,0" name="trim_distance_start_map_unit_scale"/>
              <Option type="QString" value="MM" name="trim_distance_start_unit"/>
              <Option type="QString" value="0" name="tweak_dash_pattern_on_corners"/>
              <Option type="QString" value="0" name="use_custom_dash"/>
              <Option type="QString" value="3x:0,0,0,0,0,0" name="width_map_unit_scale"/>
            </Option>
            <prop k="align_dash_pattern" v="0"/>
            <prop k="capstyle" v="square"/>
            <prop k="customdash" v="5;2"/>
            <prop k="customdash_map_unit_scale" v="3x:0,0,0,0,0,0"/>
            <prop k="customdash_unit" v="MM"/>
            <prop k="dash_pattern_offset" v="0"/>
            <prop k="dash_pattern_offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
            <prop k="dash_pattern_offset_unit" v="MM"/>
            <prop k="draw_inside_polygon" v="0"/>
            <prop k="joinstyle" v="bevel"/>
            <prop k="line_color" v="35,35,35,255"/>
            <prop k="line_style" v="solid"/>
            <prop k="line_width" v="0.26"/>
            <prop k="line_width_unit" v="MM"/>
            <prop k="offset" v="0"/>
            <prop k="offset_map_unit_scale" v="3x:0,0,0,0,0,0"/>
            <prop k="offset_unit" v="MM"/>
            <prop k="ring_filter" v="0"/>
            <prop k="trim_distance_end" v="0"/>
            <prop k="trim_distance_end_map_unit_scale" v="3x:0,0,0,0,0,0"/>
            <prop k="trim_distance_end_unit" v="MM"/>
            <prop k="trim_distance_start" v="0"/>
            <prop k="trim_distance_start_map_unit_scale" v="3x:0,0,0,0,0,0"/>
            <prop k="trim_distance_start_unit" v="MM"/>
            <prop k="tweak_dash_pattern_on_corners" v="0"/>
            <prop k="use_custom_dash" v="0"/>
            <prop k="width_map_unit_scale" v="3x:0,0,0,0,0,0"/>
            <data_defined_properties>
              <Option type="Map">
                <Option type="QString" value="" name="name"/>
                <Option name="properties"/>
                <Option type="QString" value="collection" name="type"/>
              </Option>
            </data_defined_properties>
          </layer>
        </symbol>
      </axisSymbol>
    </DiagramCategory>
  </SingleCategoryDiagramRenderer>
  <DiagramLayerSettings placement="1" zIndex="0" showAll="1" priority="0" obstacle="0" linePlacementFlags="18" dist="0">
    <properties>
      <Option type="Map">
        <Option type="QString" value="" name="name"/>
        <Option name="properties"/>
        <Option type="QString" value="collection" name="type"/>
      </Option>
    </properties>
  </DiagramLayerSettings>
  <geometryOptions removeDuplicateNodes="0" geometryPrecision="0">
    <activeChecks/>
    <checkConfiguration type="Map">
      <Option type="Map" name="QgsGeometryGapCheck">
        <Option type="double" value="0" name="allowedGapsBuffer"/>
        <Option type="bool" value="false" name="allowedGapsEnabled"/>
        <Option type="QString" value="" name="allowedGapsLayer"/>
      </Option>
    </checkConfiguration>
  </geometryOptions>
  <legend showLabelLegend="0" type="default-vector"/>
  <referencedLayers>
    <relation referencedLayer="Limites_communales_80f19120_38b7_401b_b5ed_94db29d5f2b0" referencingLayer="evol_2018_2021_35bf772c_18fa_4ab6_a2e5_57c8a304f884" layerId="Limites_communales_80f19120_38b7_401b_b5ed_94db29d5f2b0" layerName="Limites communales" dataSource="./data_occupation_sol/limites_communales.fgb" id="evol_2018__code_insee_Limites_co_code_insee" strength="Association" providerKey="ogr" name="Évolution par commune">
      <fieldRef referencedField="code_insee" referencingField="code_insee"/>
    </relation>
  </referencedLayers>
  <fieldConfiguration>
    <field configurationFlags="None" name="idobj_mult">
      <editWidget type="TextEdit">
        <config>
          <Option/>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="idobj">
      <editWidget type="TextEdit">
        <config>
          <Option/>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="niv4_18">
      <editWidget type="TextEdit">
        <config>
          <Option/>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="niv4_21">
      <editWidget type="TextEdit">
        <config>
          <Option/>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_ha">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="perim">
      <editWidget type="TextEdit">
        <config>
          <Option/>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="code_insee">
      <editWidget type="RelationReference">
        <config>
          <Option/>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_1_2">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_2_1">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_1_3">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_2_3">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_3_1">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="surf_3_2">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
    <field configurationFlags="None" name="regroupement">
      <editWidget type="TextEdit">
        <config>
          <Option type="Map">
            <Option type="bool" value="false" name="IsMultiline"/>
            <Option type="bool" value="false" name="UseHtml"/>
          </Option>
        </config>
      </editWidget>
    </field>
  </fieldConfiguration>
  <aliases>
    <alias index="0" field="idobj_mult" name=""/>
    <alias index="1" field="idobj" name=""/>
    <alias index="2" field="niv4_18" name=""/>
    <alias index="3" field="niv4_21" name=""/>
    <alias index="4" field="surf_ha" name="Surface (ha)"/>
    <alias index="5" field="perim" name=""/>
    <alias index="6" field="code_insee" name=""/>
    <alias index="7" field="surf_1_2" name="artificialisé > agricole"/>
    <alias index="8" field="surf_2_1" name="agricole > artificialisé"/>
    <alias index="9" field="surf_1_3" name="artificialisé > naturel"/>
    <alias index="10" field="surf_2_3" name="agricole > naturel"/>
    <alias index="11" field="surf_3_1" name="naturel > artificialisé"/>
    <alias index="12" field="surf_3_2" name="naturel > agricole"/>
    <alias index="13" field="regroupement" name="Évolution"/>
  </aliases>
  <defaults>
    <default applyOnUpdate="0" field="idobj_mult" expression=""/>
    <default applyOnUpdate="0" field="idobj" expression=""/>
    <default applyOnUpdate="0" field="niv4_18" expression=""/>
    <default applyOnUpdate="0" field="niv4_21" expression=""/>
    <default applyOnUpdate="0" field="surf_ha" expression=""/>
    <default applyOnUpdate="0" field="perim" expression=""/>
    <default applyOnUpdate="0" field="code_insee" expression=""/>
    <default applyOnUpdate="0" field="surf_1_2" expression=""/>
    <default applyOnUpdate="0" field="surf_2_1" expression=""/>
    <default applyOnUpdate="0" field="surf_1_3" expression=""/>
    <default applyOnUpdate="0" field="surf_2_3" expression=""/>
    <default applyOnUpdate="0" field="surf_3_1" expression=""/>
    <default applyOnUpdate="0" field="surf_3_2" expression=""/>
    <default applyOnUpdate="0" field="regroupement" expression=""/>
  </defaults>
  <constraints>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="idobj_mult" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="idobj" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="niv4_18" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="niv4_21" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_ha" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="perim" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="code_insee" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_1_2" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_2_1" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_1_3" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_2_3" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_3_1" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="surf_3_2" constraints="0"/>
    <constraint unique_strength="0" notnull_strength="0" exp_strength="0" field="regroupement" constraints="0"/>
  </constraints>
  <constraintExpressions>
    <constraint exp="" desc="" field="idobj_mult"/>
    <constraint exp="" desc="" field="idobj"/>
    <constraint exp="" desc="" field="niv4_18"/>
    <constraint exp="" desc="" field="niv4_21"/>
    <constraint exp="" desc="" field="surf_ha"/>
    <constraint exp="" desc="" field="perim"/>
    <constraint exp="" desc="" field="code_insee"/>
    <constraint exp="" desc="" field="surf_1_2"/>
    <constraint exp="" desc="" field="surf_2_1"/>
    <constraint exp="" desc="" field="surf_1_3"/>
    <constraint exp="" desc="" field="surf_2_3"/>
    <constraint exp="" desc="" field="surf_3_1"/>
    <constraint exp="" desc="" field="surf_3_2"/>
    <constraint exp="" desc="" field="regroupement"/>
  </constraintExpressions>
  <expressionfields>
    <field typeName="double precision" precision="0" comment="" subType="0" length="-1" expression="CASE&#xa;WHEN to_int((niv4_18 / 1000)) = 1 AND to_int((niv4_21 / 1000)) = 2 THEN surf_ha&#xa;ELSE 0&#xa;END" name="surf_1_2" type="6"/>
    <field typeName="double precision" precision="0" comment="" subType="0" length="-1" expression="CASE&#xa;WHEN to_int((niv4_18 / 1000)) = 2 AND to_int((niv4_21 / 1000)) = 1 THEN surf_ha&#xa;ELSE 0&#xa;END" name="surf_2_1" type="6"/>
    <field typeName="double precision" precision="0" comment="" subType="0" length="-1" expression="CASE&#xa;WHEN to_int((niv4_18 / 1000)) = 1 AND to_int((niv4_21 / 1000)) >= 3 THEN surf_ha&#xa;ELSE 0&#xa;END" name="surf_1_3" type="6"/>
    <field typeName="double precision" precision="0" comment="" subType="0" length="-1" expression="CASE&#xa;WHEN to_int((niv4_18 / 1000)) = 2 AND to_int((niv4_21 / 1000)) >= 3 THEN surf_ha&#xa;ELSE 0&#xa;END" name="surf_2_3" type="6"/>
    <field typeName="double precision" precision="0" comment="" subType="0" length="-1" expression="CASE&#xa;WHEN to_int((niv4_18 / 1000)) >= 3 AND to_int((niv4_21 / 1000)) = 1 THEN surf_ha&#xa;ELSE 0&#xa;END" name="surf_3_1" type="6"/>
    <field typeName="double precision" precision="0" comment="" subType="0" length="-1" expression="CASE&#xa;WHEN to_int((niv4_18 / 1000)) >= 3 AND to_int((niv4_21 / 1000)) = 2 THEN surf_ha&#xa;ELSE 0&#xa;END" name="surf_3_2" type="6"/>
    <field typeName="string" precision="0" comment="" subType="0" length="0" expression="'tout'" name="regroupement" type="10"/>
  </expressionfields>
  <attributeactions>
    <defaultAction key="Canvas" value="{00000000-0000-0000-0000-000000000000}"/>
  </attributeactions>
  <attributetableconfig actionWidgetStyle="dropDown" sortOrder="1" sortExpression="&quot;code_insee&quot;">
    <columns>
      <column hidden="0" type="field" name="idobj_mult" width="-1"/>
      <column hidden="0" type="field" name="idobj" width="-1"/>
      <column hidden="0" type="field" name="niv4_18" width="-1"/>
      <column hidden="0" type="field" name="niv4_21" width="130"/>
      <column hidden="0" type="field" name="surf_ha" width="243"/>
      <column hidden="0" type="field" name="perim" width="-1"/>
      <column hidden="0" type="field" name="surf_1_2" width="-1"/>
      <column hidden="0" type="field" name="surf_2_1" width="-1"/>
      <column hidden="0" type="field" name="surf_1_3" width="-1"/>
      <column hidden="0" type="field" name="surf_2_3" width="-1"/>
      <column hidden="0" type="field" name="surf_3_1" width="-1"/>
      <column hidden="0" type="field" name="surf_3_2" width="-1"/>
      <column hidden="0" type="field" name="regroupement" width="-1"/>
      <column hidden="0" type="field" name="code_insee" width="-1"/>
      <column hidden="1" type="actions" width="-1"/>
    </columns>
  </attributetableconfig>
  <conditionalstyles>
    <rowstyles/>
    <fieldstyles/>
  </conditionalstyles>
  <storedexpressions/>
  <editform tolerant="1"></editform>
  <editforminit/>
  <editforminitcodesource>0</editforminitcodesource>
  <editforminitfilepath></editforminitfilepath>
  <editforminitcode><![CDATA[# -*- coding: utf-8 -*-
"""
Les formulaires QGIS peuvent avoir une fonction Python qui est appelée lorsque le formulaire est
ouvert.

Utilisez cette fonction pour ajouter une logique supplémentaire à vos formulaires.

Entrez le nom de la fonction dans le champ 
"Fonction d'initialisation Python".
Voici un exemple:
"""
from qgis.PyQt.QtWidgets import QWidget

def my_form_open(dialog, layer, feature):
    geom = feature.geometry()
    control = dialog.findChild(QWidget, "MyLineEdit")
]]></editforminitcode>
  <featformsuppress>0</featformsuppress>
  <editorlayout>generatedlayout</editorlayout>
  <editable>
    <field editable="0" name="code_insee"/>
    <field editable="1" name="idobj"/>
    <field editable="1" name="idobj_mult"/>
    <field editable="1" name="niv4_18"/>
    <field editable="1" name="niv4_21"/>
    <field editable="1" name="perim"/>
    <field editable="0" name="regroupement"/>
    <field editable="0" name="surf_1_2"/>
    <field editable="0" name="surf_1_3"/>
    <field editable="0" name="surf_2_1"/>
    <field editable="0" name="surf_2_3"/>
    <field editable="0" name="surf_3_1"/>
    <field editable="0" name="surf_3_2"/>
    <field editable="1" name="surf_ha"/>
  </editable>
  <labelOnTop>
    <field labelOnTop="0" name="code_insee"/>
    <field labelOnTop="0" name="idobj"/>
    <field labelOnTop="0" name="idobj_mult"/>
    <field labelOnTop="0" name="niv4_18"/>
    <field labelOnTop="0" name="niv4_21"/>
    <field labelOnTop="0" name="perim"/>
    <field labelOnTop="0" name="regroupement"/>
    <field labelOnTop="0" name="surf_1_2"/>
    <field labelOnTop="0" name="surf_1_3"/>
    <field labelOnTop="0" name="surf_2_1"/>
    <field labelOnTop="0" name="surf_2_3"/>
    <field labelOnTop="0" name="surf_3_1"/>
    <field labelOnTop="0" name="surf_3_2"/>
    <field labelOnTop="0" name="surf_ha"/>
  </labelOnTop>
  <reuseLastValue>
    <field reuseLastValue="0" name="code_insee"/>
    <field reuseLastValue="0" name="idobj"/>
    <field reuseLastValue="0" name="idobj_mult"/>
    <field reuseLastValue="0" name="niv4_18"/>
    <field reuseLastValue="0" name="niv4_21"/>
    <field reuseLastValue="0" name="perim"/>
    <field reuseLastValue="0" name="regroupement"/>
    <field reuseLastValue="0" name="surf_1_2"/>
    <field reuseLastValue="0" name="surf_1_3"/>
    <field reuseLastValue="0" name="surf_2_1"/>
    <field reuseLastValue="0" name="surf_2_3"/>
    <field reuseLastValue="0" name="surf_3_1"/>
    <field reuseLastValue="0" name="surf_3_2"/>
    <field reuseLastValue="0" name="surf_ha"/>
  </reuseLastValue>
  <dataDefinedFieldProperties/>
  <widgets/>
  <previewExpression>"idobj_mult"</previewExpression>
  <mapTip></mapTip>
  <layerGeometryType>2</layerGeometryType>
</qgis>
