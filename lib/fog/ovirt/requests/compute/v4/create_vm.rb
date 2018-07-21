module Fog
  module Compute
    class Ovirt
      class V4
        class Real
          def check_for_option(opts, name)
            opts[name.to_sym] || opts[(name + "_name").to_sym]
          end

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          def process_vm_opts(opts)
            return unless check_for_option(opts, "template") && check_for_option(opts, "storagedomain")

            template_id = opts[:template] || client.system_service.templates_service.search(:name => opts[:template_name]).first.id
            template_disks = client.system_service.templates_service.template_service(template_id).get.disk_attachments
            storagedomain_id = opts[:storagedomain] || storagedomains.select { |s| s.name == opts[:storagedomain_name] }.first.id

            # Make sure the 'clone' option is set if any of the disks defined by
            # the template is stored on a different storage domain than requested
            opts[:clone] = true unless opts[:clone] == true || template_disks.empty? || template_disks.all? { |d| d.storage_domain == storagedomain_id }

            # Create disks map
            opts[:disks] = template_disks.collect { |d| { :id => d.id, :storagedomain => storagedomain_id } }
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          def create_vm(attrs)
            attrs = attrs.dup

            if attrs[:cluster].present?
              attrs[:cluster] = client.system_service.clusters_service.cluster_service(attrs[:cluster]).get
            else
              if attrs[:cluster_name].present?
                cluster = client.system_service.clusters_service.list(:search => "name=#{attrs[:cluster_name]}").first
              else
                cluster = client.system_service.clusters_service.list(:search => "datacenter=#{datacenter_hash[:name]}").first
                attrs[:cluster_name] = cluster.name
              end

              attrs[:cluster] = cluster
            end

            vms_service = client.system_service.vms_service
            attrs[:instance_type] = attrs[:instance_type].present? ? client.system_service.instance_types_service.instance_type_service(attrs[:instance_type]).get : nil

            if attrs[:template].present?
              attrs[:template] = client.system_service.templates_service.template_service(attrs[:template]).get
            else
              attrs[:template] = client.system_service.get.special_objects.blank_template
              update_os_attrs(attrs)
            end

            attrs[:comment] ||= ""
            attrs[:quota] = attrs[:quota].present? ? client.system_service.data_centers_service.data_center_service(datacenter).quotas_service.quota_service(attrs[:quota]).get : nil
            if attrs[:cores].present? || attrs[:sockets].present?
              cpu_topology = OvirtSDK4::CpuTopology.new(:cores => attrs.fetch(:cores, "1"), :sockets => attrs.fetch(:sockets, "1"))
              attrs[:cpu] = OvirtSDK4::Cpu.new(:topology => cpu_topology)
            end

            attrs[:memory_policy] = OvirtSDK4::MemoryPolicy.new(:guaranteed => attrs[:memory]) if attrs[:memory].to_i < Fog::Compute::Ovirt::DISK_SIZE_TO_GB

            # TODO: handle cloning from template
            process_vm_opts(attrs)
            new_vm = OvirtSDK4::Vm.new(attrs)
            vms_service.add(new_vm)
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          # rubocop:disable Metrics/AbcSize
          def update_os_attrs(attrs)
            attrs[:os] ||= {}
            attrs[:os][:type] ||= "Other OS"
            attrs[:os][:boot] ||= [attrs.fetch(:boot_dev1, OvirtSDK4::BootDevice::NETWORK), attrs.fetch(:boot_dev2, OvirtSDK4::BootDevice::HD)]
            attrs[:os][:boot] = attrs[:os][:boot].without(attrs["first_boot_dev"]).prepend(attrs["first_boot_dev"]) if attrs["first_boot_dev"]

            attrs[:os] = OvirtSDK4::OperatingSystem.new(:type => attrs[:os][:type], :boot => OvirtSDK4::Boot.new(:devices => attrs[:os][:boot]))
          end
          # rubocop:enable Metrics/AbcSize
        end

        class Mock
          def create_vm(_attrs)
            xml = read_xml("vm.xml")
            OvirtSDK4::Reader.read(Nokogiri::XML(xml).root.to_s)
          end
        end
      end
    end
  end
end
