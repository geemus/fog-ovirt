Shindo.tests("Fog::Ovirt::Compute.new", ["ovirt"]) do
  compute = Fog::Ovirt::Compute.new

  tests("Compute attributes") do
    %w[ovirt_attrs].each do |attr|
      test("it should respond to #{attr}") { compute.respond_to? attr }
    end
  end

  tests("Compute collections") do
    %w[servers templates clusters interfaces operating_systems].each do |collection|
      test("it should respond to #{collection}") { compute.respond_to? collection }
    end
  end

  tests("Compute requests") do
    %w[ add_interface create_vm datacenters destroy_interface destroy_vm get_cluster get_template
        get_virtual_machine list_clusters list_networks list_template_interfaces list_templates
        list_virtual_machines list_vm_interfaces storage_domains update_interface update_vm vm_action
        vm_start_with_cloudinit api_version update_volume].each do |collection|
      test("it should respond to #{collection}") { compute.respond_to? collection }
    end
  end

  tests("compute v4 with_initialization request") do
    compute = Fog::Ovirt::Compute.new(:api_version => "v4")
    test("it should respond to vm_start_with_initialization") { compute.respond_to? "vm_start_with_initialization" }
  end
end
