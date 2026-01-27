PROGRAM Blink_LED
  VAR
    Toggle : BOOL := FALSE;
    Counter : INT := 0;
  END_VAR

  Counter := Counter + 1;
  IF Counter >= 1000 THEN
    Toggle := NOT Toggle;
    Counter := 0;
  END_IF;
END_PROGRAM
