-- VEDS Verification Main Program
-- Entry point for standalone testing and SPARK proof runs

with Ada.Text_IO; use Ada.Text_IO;
with VEDS_Types; use VEDS_Types;
with VEDS_Constraints;
with VEDS_Route_Safety;

procedure VEDS_Verify_Main is

   procedure Print_Separator is
   begin
      Put_Line ("========================================");
   end Print_Separator;

   procedure Test_Wage_Constraints is
      Result : Constraint_Result;
   begin
      Print_Separator;
      Put_Line ("Testing Wage Constraints (ILO Compliance)");
      Print_Separator;

      -- Test: German wage above minimum
      Result := VEDS_Constraints.Check_Minimum_Wage (1500, "DE");
      Put_Line ("DE wage 1500 cents: " &
                (if Result.Passed then "PASS" else "FAIL"));

      -- Test: German wage below minimum
      Result := VEDS_Constraints.Check_Minimum_Wage (1000, "DE");
      Put_Line ("DE wage 1000 cents: " &
                (if Result.Passed then "PASS" else "FAIL") &
                " (expected FAIL)");

      -- Test: Singapore (no statutory minimum)
      Result := VEDS_Constraints.Check_Minimum_Wage (500, "SG");
      Put_Line ("SG wage 500 cents:  " &
                (if Result.Passed then "PASS" else "FAIL"));

      New_Line;
   end Test_Wage_Constraints;

   procedure Test_Working_Time_Constraints is
      Result : Constraint_Result;
   begin
      Print_Separator;
      Put_Line ("Testing Working Time (EU Directive)");
      Print_Separator;

      -- Test: Within limit
      Result := VEDS_Constraints.Check_Working_Time (40);
      Put_Line ("40h/week: " & (if Result.Passed then "PASS" else "FAIL"));

      -- Test: At limit
      Result := VEDS_Constraints.Check_Working_Time (48);
      Put_Line ("48h/week: " & (if Result.Passed then "PASS" else "FAIL"));

      -- Test: Over limit (soft violation)
      Result := VEDS_Constraints.Check_Working_Time (55);
      Put_Line ("55h/week: " & (if Result.Passed then "PASS" else "FAIL") &
                " hard=" & (if Result.Is_Hard then "Y" else "N"));

      -- Test: Way over limit (hard violation)
      Result := VEDS_Constraints.Check_Working_Time (70);
      Put_Line ("70h/week: " & (if Result.Passed then "PASS" else "FAIL") &
                " hard=" & (if Result.Is_Hard then "Y" else "N"));

      New_Line;
   end Test_Working_Time_Constraints;

   procedure Test_Carbon_Constraints is
      Result : Constraint_Result;
      Carbon : Segment_Carbon;
   begin
      Print_Separator;
      Put_Line ("Testing Carbon Constraints");
      Print_Separator;

      -- Test: Within budget
      Result := VEDS_Constraints.Check_Carbon_Budget (4000, 5000);
      Put_Line ("4000kg vs 5000kg budget: " &
                (if Result.Passed then "PASS" else "FAIL"));

      -- Test: Over budget
      Result := VEDS_Constraints.Check_Carbon_Budget (6000, 5000);
      Put_Line ("6000kg vs 5000kg budget: " &
                (if Result.Passed then "PASS" else "FAIL") &
                " (expected FAIL)");

      -- Test: Carbon calculation (maritime)
      Carbon := VEDS_Constraints.Calculate_Segment_Carbon
        (Distance_Km => 10000,
         Weight_Kg   => 20000,
         Mode        => Maritime);
      Put_Line ("Maritime 10000km x 20t: " & Carbon'Image & " kg CO2");

      -- Test: Carbon calculation (air)
      Carbon := VEDS_Constraints.Calculate_Segment_Carbon
        (Distance_Km => 10000,
         Weight_Kg   => 20000,
         Mode        => Air);
      Put_Line ("Air 10000km x 20t:      " & Carbon'Image & " kg CO2");

      New_Line;
   end Test_Carbon_Constraints;

   procedure Test_Safety_Constraints is
      Result : Constraint_Result;
   begin
      Print_Separator;
      Put_Line ("Testing Safety Constraints");
      Print_Separator;

      -- Test: Good safety score
      Result := VEDS_Constraints.Check_Safety_Score (0.85, 0.70);
      Put_Line ("Safety 0.85 vs 0.70 threshold: " &
                (if Result.Passed then "PASS" else "FAIL"));

      -- Test: Borderline safety
      Result := VEDS_Constraints.Check_Safety_Score (0.70, 0.70);
      Put_Line ("Safety 0.70 vs 0.70 threshold: " &
                (if Result.Passed then "PASS" else "FAIL"));

      -- Test: Poor safety
      Result := VEDS_Constraints.Check_Safety_Score (0.50, 0.70);
      Put_Line ("Safety 0.50 vs 0.70 threshold: " &
                (if Result.Passed then "PASS" else "FAIL") &
                " hard=" & (if Result.Is_Hard then "Y" else "N"));

      New_Line;
   end Test_Safety_Constraints;

   procedure Test_Sanctions is
      Result : Constraint_Result;
   begin
      Print_Separator;
      Put_Line ("Testing Sanctions Compliance");
      Print_Separator;

      -- Test: Clear country
      Result := VEDS_Constraints.Check_Country_Sanctions ("DE");
      Put_Line ("Germany (DE):     " &
                (if Result.Passed then "CLEAR" else "BLOCKED"));

      -- Test: Clear country
      Result := VEDS_Constraints.Check_Country_Sanctions ("NL");
      Put_Line ("Netherlands (NL): " &
                (if Result.Passed then "CLEAR" else "BLOCKED"));

      -- Test: Sanctioned country
      Result := VEDS_Constraints.Check_Country_Sanctions ("KP");
      Put_Line ("North Korea (KP): " &
                (if Result.Passed then "CLEAR" else "BLOCKED") &
                " (expected BLOCKED)");

      -- Test: Sanctioned country
      Result := VEDS_Constraints.Check_Country_Sanctions ("IR");
      Put_Line ("Iran (IR):        " &
                (if Result.Passed then "CLEAR" else "BLOCKED") &
                " (expected BLOCKED)");

      New_Line;
   end Test_Sanctions;

   procedure Test_Combined_Evaluation is
      Result : VEDS_Constraints.Route_Constraints;
      Test_Entity : constant Entity_ID := "test-entity-001                     ";
   begin
      Print_Separator;
      Put_Line ("Testing Combined Constraint Evaluation");
      Print_Separator;

      -- Test: All passing
      Result := VEDS_Constraints.Evaluate_All_Constraints
        (Wage          => 1500,
         Country       => "DE",
         Weekly_Hours  => 40,
         Carbon        => 4000,
         Carbon_Budget => 5000,
         Safety        => 0.85,
         Entity        => Test_Entity);

      Put_Line ("All-passing scenario:");
      Put_Line ("  Wage OK:         " & (if Result.Wage_OK then "Y" else "N"));
      Put_Line ("  Working Time OK: " & (if Result.Working_Time_OK then "Y" else "N"));
      Put_Line ("  Carbon OK:       " & (if Result.Carbon_OK then "Y" else "N"));
      Put_Line ("  Safety OK:       " & (if Result.Safety_OK then "Y" else "N"));
      Put_Line ("  Sanctions OK:    " & (if Result.Sanctions_OK then "Y" else "N"));
      Put_Line ("  All Hard Pass:   " & (if Result.All_Hard_Pass then "Y" else "N"));
      Put_Line ("  Overall Pass:    " & (if Result.Overall_Pass then "Y" else "N"));

      New_Line;

      -- Test: Some failures
      Result := VEDS_Constraints.Evaluate_All_Constraints
        (Wage          => 800,   -- Below minimum
         Country       => "DE",
         Weekly_Hours  => 55,    -- Over limit
         Carbon        => 6000,  -- Over budget
         Carbon_Budget => 5000,
         Safety        => 0.85,
         Entity        => Test_Entity);

      Put_Line ("Failing scenario:");
      Put_Line ("  Wage OK:         " & (if Result.Wage_OK then "Y" else "N") & " (expected N)");
      Put_Line ("  Working Time OK: " & (if Result.Working_Time_OK then "Y" else "N") & " (expected N)");
      Put_Line ("  Carbon OK:       " & (if Result.Carbon_OK then "Y" else "N") & " (expected N)");
      Put_Line ("  Safety OK:       " & (if Result.Safety_OK then "Y" else "N"));
      Put_Line ("  Sanctions OK:    " & (if Result.Sanctions_OK then "Y" else "N"));
      Put_Line ("  Overall Pass:    " & (if Result.Overall_Pass then "Y" else "N") & " (expected N)");

      New_Line;
   end Test_Combined_Evaluation;

   procedure Test_Haversine is
      Dist : Route_Distance;
   begin
      Print_Separator;
      Put_Line ("Testing Haversine Distance");
      Print_Separator;

      -- Shanghai to Rotterdam
      Dist := VEDS_Route_Safety.Haversine_Distance
        (31.2304, 121.4737, 51.9225, 4.4792);
      Put_Line ("Shanghai to Rotterdam: " & Dist'Image & " km");

      -- London to New York
      Dist := VEDS_Route_Safety.Haversine_Distance
        (51.5074, -0.1278, 40.7128, -74.0060);
      Put_Line ("London to New York:    " & Dist'Image & " km");

      -- Singapore to Dubai
      Dist := VEDS_Route_Safety.Haversine_Distance
        (1.3521, 103.8198, 25.2048, 55.2708);
      Put_Line ("Singapore to Dubai:    " & Dist'Image & " km");

      New_Line;
   end Test_Haversine;

begin
   Put_Line ("");
   Put_Line ("VEDS SPARK Verification Test Suite");
   Put_Line ("===================================");
   Put_Line ("");

   Test_Wage_Constraints;
   Test_Working_Time_Constraints;
   Test_Carbon_Constraints;
   Test_Safety_Constraints;
   Test_Sanctions;
   Test_Combined_Evaluation;
   Test_Haversine;

   Print_Separator;
   Put_Line ("All tests completed.");
   Print_Separator;
end VEDS_Verify_Main;
