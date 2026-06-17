module h_a_tb;


reg A;
reg B;


wire Sum;
wire Carry;


h_a uut (
    .A(A),
    .B(B),
    .Sum(Sum),
    .Carry(Carry)
);

initial begin

    $display("A B | Sum Carry");
    $display("----------------");

    A = 0; B = 0;
    #10;
    $display("%b %b |  %b    %b", A, B, Sum, Carry);

    A = 0; B = 1;
    #10;
    $display("%b %b |  %b    %b", A, B, Sum, Carry);

    A = 1; B = 0;
    #10;
    $display("%b %b |  %b    %b", A, B, Sum, Carry);

    A = 1; B = 1;
    #10;
    $display("%b %b |  %b    %b", A, B, Sum, Carry);

    $finish;

end

endmodule
