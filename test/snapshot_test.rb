require_relative 'spec_helper'
require 'yast'
require_relative '../src/lib/snapper/snapshot.rb'

module Yast2
  module Snapper
    describe Snapshot do
       let(:outputh_path) { load_yaml_fixture("snapper-list.yml") }
       
       before do
        allow(Yast::Snapper).to receive(:current_config).and_return("var")
        allow(SnapshotDBus).to receive(:list_configs).and_return(["opt","var"])
        allow(SnapshotDBus).to receive(:list_snapshots).with("var").and_return(outputh_path)
        allow(SnapshotDBus).to receive(:list_snapshots).with("opt").and_return([])
      end

      describe ".all" do
        it "returns snapshots for all configs" do
          expect(Snapshot.all.size).to eq (5)
        end

        context "with var config" do
          it "returns a snapshot list for current Snapper config" do
            expect(Snapshot.all.size).to eq (5)
          end
        end
      end

    end
  end
end
