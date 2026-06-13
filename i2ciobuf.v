`timescale 1 ps / 1 ps

module i2ciobuf_iobuf_bidir_amo
(
	datain,
	dataio,
	dataout,
	oe
);

	input   [0:0]  datain;
	inout   [0:0]  dataio;
	output  [0:0]  dataout;
	input   [0:0]  oe;

	wire [0:0] wire_ibufa_o;
	wire [0:0] wire_obufa_o;

	cyclonev_io_ibuf ibufa_0
	(
		.i(dataio),
		.o(wire_ibufa_o[0:0]),
		.dynamicterminationcontrol(1'b0),
		.ibar(1'b0)
	);

	defparam
		ibufa_0.bus_hold = "false",
		ibufa_0.differential_mode = "false",
		ibufa_0.lpm_type = "cyclonev_io_ibuf";

	cyclonev_io_obuf obufa_0
	(
		.i(datain),
		.o(wire_obufa_o[0:0]),
		.obar(),
		.oe(oe),
		.dynamicterminationcontrol(1'b0),
		.parallelterminationcontrol({16{1'b0}}),
		.seriesterminationcontrol({16{1'b0}}),
		.devoe(1'b1)
	);

	defparam
		obufa_0.bus_hold = "false",
		obufa_0.open_drain_output = "true",
		obufa_0.lpm_type = "cyclonev_io_obuf";

	assign dataio = wire_obufa_o;
	assign dataout = wire_ibufa_o;

endmodule

`timescale 1 ps / 1 ps

module i2ciobuf (
	datain,
	oe,
	dataio,
	dataout
);

	input  [0:0] datain;
	input  [0:0] oe;
	inout  [0:0] dataio;
	output [0:0] dataout;

	wire [0:0] sub_wire0;
	wire [0:0] dataout = sub_wire0[0:0];

	i2ciobuf_iobuf_bidir_amo i2ciobuf_iobuf_bidir_amo_component (
		.datain(datain),
		.oe(oe),
		.dataio(dataio),
		.dataout(sub_wire0)
	);

endmodule
