package com.microsoft.azure.samples.dao;

import com.microsoft.azure.samples.model.TodoItem;

import java.util.List;

public interface ItemManagement {

    public void addTodoItem(TodoItem item);

    public void updateTodoItem(List<TodoItem> items);

}
