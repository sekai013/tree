require "tree/version"
require "pathname"

module Tree

	class Command

		module Options

			def self.parse!(argv)
				options = {}
				option_parser = create_option_parser
				
				begin
					option_parser.order! argv
					options[:path]     = Pathname(argv.shift || Dir.pwd).expand_path.to_path
					options[:filename] = argv.shift || 'directory_structure.txt'
				end

				options
			end

			private

			def self.create_option_parser
				OptionParser.new do |opt|
					opt.banner = "Usage: #{opt.program_name} [-h|--help][-v|--version] [<path>]"
					opt.separator ''
					opt.on_head '-h', '--help', 'Show this message' do |v|
						puts opt.help
					end

					opt.on_head '-v', '--version', 'Show program version' do |v|
						opt.version = Tree::VERSION
						puts opt.ver
						exit
					end
				end
			end

		end

		def self.run(argv)
			new(argv).execute
		end

		def initialize(argv)
			@argv = argv
		end

		def execute
			options = Options.parse! @argv
			raise ArgumentError, "Directory Not Found: #{options[:path]}" unless Dir.exist? options[:path]
			ignore_path = Pathname.new('~/.treeignore').expand_path
			ignore =
				if ignore_path.file?
					File.read(ignore_path.to_path).split "\n"
				else
					[]
				end

			Dir.open options[:path] do |dir|
				structure = check_structure dir
				structure_str = make_structure_str structure, Pathname.new(options[:path]).basename.to_path, ignore
				puts structure_str

				File.open options[:filename], 'w' do |f|
					f.write structure_str
				end
			end
		rescue ArgumentError, OptionParser::MissingArgument, OptionParser::InvalidOption => err
			abort err.message
		end

		private

		def check_structure(dir)
			result = {
				files: []
			}

			(dir.entries - [".", ".."]).each do |entry|
				full_path = "#{dir.path}/#{entry}"

				if Dir.exist? full_path
					nested_dir = Dir.open full_path
					result[entry.to_sym] = check_structure nested_dir
				else
					result[:files].push entry
				end
			end

			result
		end

		def make_structure_str(structure, dir_name, ignore)
			result = "#{dir_name}/ "

			unless ignore.include? dir_name
				space_size = result.size + full_width_count(result)
				first_line = true
				last_line = false

				structure[:files].each_with_index do |file, index|
					if first_line
						if structure.keys.size == 1 and structure[:files].size == 1
							result += "━ #{file}\n"
						else
							result += "┳ #{file}\n"
						end
						first_line = false
					elsif structure.keys.size == 1 and index == structure[:files].size - 1
						result += " " * space_size + "┗ #{file}\n"
						last_line = true
					else
						result += " " * space_size + "┣ #{file}\n"
					end
				end

				(structure.keys - [:files]).each_with_index do |key, index|
					nested_structure = make_structure_str structure[key], key.to_s, ignore

					nested_structure.each_line.with_index do |line, i|

						if i == 0

							if first_line
								if structure.keys.size == 2
									result += "━ #{line}"
								else 
									result += "┳ #{line}"
								end
								first_line = false
							elsif index == structure.keys.size - 2
								result += " " * space_size + "┗ #{line}"
								last_line = true
							else
								result += " " * space_size + "┣ #{line}"
							end

						else

							if last_line
								result += " " * (space_size + 2) + line
							else
								result += " " * space_size + "┃ #{line}"
							end

						end

					end

				end

				if structure[:files].size == 0 and structure.keys.size == 1
					result += "\n"
				end
			else
				result += "\n"
			end

			result
		end

		def full_width_count(string)
			string.each_char.select{ |char| !(/[ -~]/.match(char)) }.count
		end

	end

end
