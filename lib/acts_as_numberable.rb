# Copyright 2011-2012 Rice University. Licensed under the Affero General Public 
# License version 3 or later.  See the COPYRIGHT file for details.

module ActsAsNumberable

  def acts_as_numberable(options={})
    configuration = {}
    configuration.update(options) if options.is_a?(Hash)
   
    container_column = nil
    container_column_symbol = nil

    # When calling assign_number below, you normally want to run a query against
    # self.class to figure out what the next available number is; however, if the 
    # class acting as numberable is using STI, self.class will return the child class
    # which is likely not what we want.  In these cases, we can specify the base
    # class here (the class that has the same name as the DB table) so that it is used
    # instead.
    table_class = configuration[:table_class]
    
    if !configuration[:container].nil?
      container_column = configuration[:container].to_s + "_id"
      container_column_symbol = configuration[:container].to_sym
    end
    
    uniqueness_scope_string = container_column.nil? ? "" : ":scope => :#{container_column},"
   
    class_eval <<-EOV
      include ActsAsNumberable::BasicInstanceMethods
    
      before_validation :assign_number, :on => :create
      
      validates :number, :uniqueness => { #{uniqueness_scope_string}
                                          :allow_nil => true},
                         :numericality => { :only_integer => true, 
                                            :greater_than => 0,
                                            :allow_nil => true }    

      
      after_destroy :mark_as_destroyed
      
      attr_accessor :destroyed
      attr_accessor :changed_sets

      attr_protected :number
    
      scope :ordered, order('number ASC')
      scope :reverse_ordered, order('number DESC')
      
      def self.sort!(sorted_ids)
        return if sorted_ids.blank?
        items = []
        ActiveRecord::Base.transaction do
          items = find_in_specified_order(sorted_ids)
          
          items.each do |item|
            item.number = nil
            item.save!
          end
          
          items.each_with_index do |item, ii| 
            item.number = ii + 1
            item.save!
          end
        end
        items
      end

      def table_class
        #{table_class}
      end
    EOV
   
   
    if !configuration[:container].nil?
      class_eval <<-EOV
        include ActsAsNumberable::ContainerInstanceMethods
      
        # When we had nested acts_as_numberables, there were cases where the
        # objects were having their numbers changed (as their peers were being
        # removed from the container), but then when it came time to delete those 
        # objects they still had their old number.  So just reload before
        # destroy.
        before_destroy {self.reload}
      
        after_destroy :remove_from_container!
      
        def container_column
          '#{container_column}'
        end

        def container
          '#{configuration[:container]}'
        end

        def table_class
          #{table_class}
        end
      
      EOV
      
    end
       
  end
   
  module BasicInstanceMethods
    protected

    def my_class
      table_class || self.class
    end

    def assign_number
      self.number ||= my_class.count + 1
    end
     
    def mark_as_destroyed
      destroyed = true
    end
  end
   
  module ContainerInstanceMethods
    def move_to_container!(new_container)
      return if new_container.id == self.send(container_column)
      ActiveRecord::Base.transaction do
        remove_from_container!

        self.send container + "=", new_container
        #self.lesson_exercise_set = new_lesson_exercise_set

        self.assign_number
        self.save!
        self.changed_sets = true
      end
    end

    def remove_from_container!
      logger.debug("In remove_from_container: " + my_class.name + " " + self.id.to_s)
      
      later_items = my_class.where(container_column => self.send(container_column))
                            .where{number.gt my{number}}

      logger.debug("later_items:" + later_items.inspect)
      logger.debug("is destroyed?: " + self.destroyed.inspect)

      if !self.destroyed
        self.number = nil
        self.send container_column + '=', nil
        self.save!
      end

      # Do this to make sure that the reordering below doesn't 
      # cause a number to be duplicated temporarily (which would
      # cause a validation error)
      later_items.sort_by!{|item| item.number}

      later_items.each do |later|
        later.number = later.number-1
        later.save!
      end
    end
    
    def my_class
      table_class || self.class
    end

    protected
    
    def assign_number
      self.number ||= my_class
                      .where(container_column => self.send(container_column))
                      .count + 1
    end
  end
  
end
 
ActiveRecord::Base.extend ActsAsNumberable