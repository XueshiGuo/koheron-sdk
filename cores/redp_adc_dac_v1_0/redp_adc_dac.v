/**
 * $Id: red_pitaya_analog.v 964 2014-01-24 12:58:17Z matej.oblak $
 *
 * @brief Red Pitaya analog module. Connects to ADC & DAC pins.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */



/**
 * GENERAL DESCRIPTION:
 *
 * Interace module between fast ADC and DAC IC.  
 *
 *
 *                 /------------\      
 *   ADC DAT ----> | RAW -> 2's | ----> ADC DATA TO USER
 *                 \------------/
 *                       ^
 *                       |
 *                    /-----\
 *   ADC CLK -------> | PLL |
 *                    \-----/
 *                       |
 *                       Ë‡
 *                 /------------\
 *   DAC DAT <---- | RAW <- 2's | <---- DAC DATA FROM USER
 *                 \------------/
 *                       |
 *                       Ë‡
 *                   /-------\
 *   DAC PWM <------ |  PWM  | <------- SLOW DAC DATA FROM USER
 *                   \-------/
 *
 *
 * ADC clock is used for main clock domain, from this double clock is made which
 * is used for driving DAC IC (using DDR transfer) and PWM counters.
 *
 * ADC interface gives unsigned number format with negative slope because 
 * input amplifier. This is transfomed into 2's complement wich is more usable in
 * digital world.
 *
 * For sending data to DAC values has to be first translated from 2's format to 
 * unsigned format, where negative output amplifier gain is taken into account.
 * Interface to DAC is DDR, positive edge used for CHA and negative for CHB.
 
 * PWM in created with counter running on 2xDAC clock. Each 16 cycles of PWM_FULL
 * counts new value is taken. Upper 8 bits are used for dac_pwm_vcnt which defines
 * PWM rate of output. This repeates 16x times, where lower 16bits of input data
 * defines if ration of dac_pwm_vcnt is one cycle more.
 * 
 */


`timescale 1 ns / 1 ps

module rp_adc_dac #
(
)
(
  // ADC IC
  input    [ 14-1: 0] adc_dat_a_i        ,  //!< ADC IC CHA data connection
  input    [ 14-1: 0] adc_dat_b_i        ,  //!< ADC IC CHB data connection
  input               adc_clk_p_i        ,  //!< ADC IC clock P connection
  input               adc_clk_n_i        ,  //!< ADC IC clock N connection
  output [ 2-1: 0]    adc_clk_source          ,  // optional ADC clock source
  //output              adc_enc_p_o	 ,
  //output              adc_enc_n_o	 ,
  output              adc_cdcs_o         ,  // ADC clock duty cycle stabilizer

  
  // DAC IC
  output   [ 14-1: 0] dac_dat_o          ,  //!< DAC IC combined data
  output              dac_wrt_o          ,  //!< DAC IC write enable
  output              dac_sel_o          ,  //!< DAC IC channel select
  output              dac_clk_o          ,  //!< DAC IC clock
  output              dac_rst_o          ,  //!< DAC IC reset
  
  // PWM DAC
  //output   [  4-1: 0] dac_pwm_o          ,  //!< DAC PWM - driving RC
  
  // user interface
  output   [ 14-1: 0] adc_dat_a_o        ,  //!< ADC CHA data
  output   [ 14-1: 0] adc_dat_b_o        ,  //!< ADC CHB data
  output              adc_clk_o          ,  //!< ADC clock
  input               adc_rst_i          ,  //!< ADC reset - active low
  output              ser_clk_o          ,  //!< fast serial clock

  input    [ 14-1: 0] dac_dat_a_i        ,  //!< DAC CHA data
  input    [ 14-1: 0] dac_dat_b_i           //!< DAC CHB data

  //input    [ 24-1: 0] dac_pwm_a_i        ,  //!< DAC PWM CHA
  //input    [ 24-1: 0] dac_pwm_b_i        ,  //!< DAC PWM CHB
  //input    [ 24-1: 0] dac_pwm_c_i        ,  //!< DAC PWM CHC
  //input    [ 24-1: 0] dac_pwm_d_i        ,  //!< DAC PWM CHD
  //output              dac_pwm_sync_o        //!< DAC PWM sync  

);
//---------------------------------------------------------------------------------
//
//  Analog peripherials (red_pitaya_top.v)

// ADC clock duty cycle stabilizer is enabled
assign adc_cdcs_o = 1'b1 ;

// generating ADC clock is disabled
assign adc_clk_source = 2'b10;
//assign adc_enc_p_o = 1'b1;
//assign adc_enc_n_o = 1'b0;

//---------------------------------------------------------------------------------
//
//  ADC input registers

reg  [14-1: 0] adc_dat_a  ;
reg  [14-1: 0] adc_dat_b  ;
wire           adc_clk_in ;
wire           adc_clk    ;

IBUFDS i_clk ( .I(adc_clk_p_i), .IB(adc_clk_n_i), .O(adc_clk_in));  // differential clock input
BUFG i_adc_buf  (.O(adc_clk), .I(adc_clk_in)); // use global clock buffer

always @(posedge adc_clk) begin
   adc_dat_a <= adc_dat_a_i[14-1:0]; // lowest 2 bits reserved for 16bit ADC
   adc_dat_b <= adc_dat_b_i[14-1:0];
end
    
assign adc_dat_a_o = {adc_dat_a[14-1], ~adc_dat_a[14-2:0]}; // transform into 2's complement (negative slope)
assign adc_dat_b_o = {adc_dat_b[14-1], ~adc_dat_b[14-2:0]};
assign adc_clk_o   =  adc_clk ;





//---------------------------------------------------------------------------------
//
//  Fast DAC - DDR interface

wire  dac_clk_fb      ;
wire  dac_clk_fb_buf  ;
wire  dac_clk_out     ;
wire  dac_2clk_out    ;
wire  dac_clk         ;
wire  dac_2clk        ;
wire  dac_locked      ;
reg   dac_rst         ;
wire  ser_clk_out     ;
wire  dac_2ph_out     ;
wire  dac_2ph         ;

PLLE2_ADV
#(
   .BANDWIDTH            ( "OPTIMIZED"   ),
   .COMPENSATION         ( "ZHOLD"       ),
   .DIVCLK_DIVIDE        (  1            ),
   .CLKFBOUT_MULT        (  8            ),
   .CLKFBOUT_PHASE       (  0.000        ),
   .CLKOUT0_DIVIDE       (  8            ),
   .CLKOUT0_PHASE        (  0.000        ),
   .CLKOUT0_DUTY_CYCLE   (  0.5          ),
   .CLKOUT1_DIVIDE       (  4            ),
   .CLKOUT1_PHASE        (  0.000        ),
   .CLKOUT1_DUTY_CYCLE   (  0.5          ),
   .CLKOUT2_DIVIDE       (  4            ),
   .CLKOUT2_PHASE        ( -45.000       ),
   .CLKOUT2_DUTY_CYCLE   (  0.5          ),
   .CLKOUT3_DIVIDE       (  4            ),  // 4->250MHz, 2->500MHz
   .CLKOUT3_PHASE        (  0.000        ),
   .CLKOUT3_DUTY_CYCLE   (  0.5          ),
   .CLKIN1_PERIOD        (  8.000        ),
   .REF_JITTER1          (  0.010        )
)
i_dac_plle2
(
   // Output clocks
   .CLKFBOUT     (  dac_clk_fb     ),
   .CLKOUT0      (  dac_clk_out    ),
   .CLKOUT1      (  dac_2clk_out   ),
   .CLKOUT2      (  dac_2ph_out    ),
   .CLKOUT3      (  ser_clk_out    ),
   .CLKOUT4      (        ),
   .CLKOUT5      (        ),
   // Input clock control
   .CLKFBIN      (  dac_clk_fb_buf ),
   .CLKIN1       (  adc_clk        ),
   .CLKIN2       (  1'b0           ),
   // Tied to always select the primary input clock
   .CLKINSEL     (  1'b1           ),
   // Ports for dynamic reconfiguration
   .DADDR        (  7'h0           ),
   .DCLK         (  1'b0           ),
   .DEN          (  1'b0           ),
   .DI           (  16'h0          ),
   .DO           (        ),
   .DRDY         (        ),
   .DWE          (  1'b0           ),
   // Other control and status signals
   .LOCKED       (  dac_locked     ),
   .PWRDWN       (  1'b0           ),
   .RST          ( !adc_rst_i      )
);

BUFG i_dacfb_buf   (.O(dac_clk_fb_buf), .I(dac_clk_fb));
BUFG i_dac1_buf    (.O(dac_clk),        .I(dac_clk_out));
BUFG i_dac2_buf    (.O(dac_2clk),       .I(dac_2clk_out));
BUFG i_dac2ph_buf  (.O(dac_2ph),        .I(dac_2ph_out));
BUFG i_ser_buf     (.O(ser_clk_o),      .I(ser_clk_out));




reg  [14-1: 0] dac_dat_a  ;
reg  [14-1: 0] dac_dat_b  ;

// output registers + signed to unsigned (also to negative slope)
always @(posedge dac_clk) begin
   dac_dat_a <= {dac_dat_a_i[14-1], ~dac_dat_a_i[14-2:0]};
   dac_dat_b <= {dac_dat_b_i[14-1], ~dac_dat_b_i[14-2:0]};
   dac_rst   <= !dac_locked;
end


ODDR oddr_dac_clk ( .Q(dac_clk_o), .D1(1'b0), .D2(1'b1), .C(dac_2ph),  .CE(1'b1), .R(dac_rst), .S(1'b0) );
ODDR oddr_dac_wrt ( .Q(dac_wrt_o), .D1(1'b0), .D2(1'b1), .C(dac_2clk), .CE(1'b1), .R(dac_rst), .S(1'b0) );
ODDR oddr_dac_sel ( .Q(dac_sel_o), .D1(1'b1), .D2(1'b0), .C(dac_clk ), .CE(1'b1), .R(dac_rst), .S(1'b0) );
ODDR oddr_dac_rst ( .Q(dac_rst_o), .D1(dac_rst), .D2(dac_rst), .C(dac_clk ), .CE(1'b1), .R(1'b0), .S(1'b0) );

ODDR oddr_dac_dat [14-1:0] (.Q(dac_dat_o), .D1(dac_dat_b), .D2(dac_dat_a), .C(dac_clk), .CE(1'b1), .R(dac_rst), .S(1'b0));

endmodule

